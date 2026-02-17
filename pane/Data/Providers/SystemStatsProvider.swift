import Darwin
import Foundation

struct SystemStatsProvider {
    func fetch() -> SystemStatsSnapshot {
        let cpu = cpuApproximation()
        let memory = memoryUsagePercent()
        let storage = storageUsagePercent()

        return SystemStatsSnapshot(
            cpuPercent: cpu,
            memoryPercent: memory,
            storagePercent: storage,
            updatedAt: Date()
        )
    }

    private func cpuApproximation() -> Double? {
        var averages = [Double](repeating: 0, count: 3)
        guard getloadavg(&averages, 3) == 3 else {
            return nil
        }

        let cores = max(1, ProcessInfo.processInfo.activeProcessorCount)
        let value = (averages[0] / Double(cores)) * 100
        return max(0, min(100, value))
    }

    private func memoryUsagePercent() -> Double? {
        let total = Double(ProcessInfo.processInfo.physicalMemory)
        guard total > 0 else {
            return nil
        }

        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)

        let result = withUnsafeMutablePointer(to: &stats) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { rebound in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, rebound, &count)
            }
        }

        guard result == KERN_SUCCESS else {
            return nil
        }

        let pageSize = Double(vm_kernel_page_size)
        let usedPages = Double(stats.active_count + stats.wire_count + stats.compressor_page_count + stats.inactive_count)
        let used = usedPages * pageSize
        return max(0, min(100, (used / total) * 100))
    }

    private func storageUsagePercent() -> Double? {
        do {
            let attrs = try FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory())
            guard let total = attrs[.systemSize] as? NSNumber,
                  let free = attrs[.systemFreeSize] as? NSNumber,
                  total.doubleValue > 0 else {
                return nil
            }
            let used = total.doubleValue - free.doubleValue
            return max(0, min(100, (used / total.doubleValue) * 100))
        } catch {
            return nil
        }
    }
}
