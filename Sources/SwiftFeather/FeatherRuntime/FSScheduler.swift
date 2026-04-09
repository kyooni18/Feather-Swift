class FSSchedulerInstantTask {
    let task: () -> Void
    let priority: Int8
    let id: UInt64

    init(
        task: @escaping () -> Void,
        priority: Int = 0,
        id: UInt64 = 0
        ) {
        self.task = task
        self.priority = Int8(priority)
        self.id = id
    }
}

class FSSchedulerTimedTask {
    let task: () -> Void
    let priority: Int8
    let executionTime: UInt64
    let id: UInt64

    let sourceType: SourceType
    enum SourceType {
        case deferred
        case repeative(parentId: UInt64)
    }

    init(
        task: @escaping () -> Void,
        priority: Int = 0,
        executionTime: UInt64,
        id: UInt64 = 0,
        sourceType: SourceType = .deferred
    ) {
        self.task = task
        self.priority = Int8(priority)
        self.executionTime = executionTime
        self.id = id
        self.sourceType = sourceType
    }
}

class FSSchedulerDeferredTask {
    let task: () -> Void
    let priority: Int8
    let executionTime: UInt64
    let id: UInt64

    init(
        task: @escaping () -> Void,
        priority: Int = 0,
        executionTime: UInt64,
        id: UInt64 = 0
        ) {
        self.task = task
        self.priority = Int8(priority)
        self.executionTime = executionTime
        self.id = id
    }
}

class FSSchedulerRepeativeTask {
    enum RepeatCycleType {
        case relative, absolute
    }

    let task: () -> Void
    let priority: Int8
    let startTime: UInt64
    let period: UInt64
    let repeatType: RepeatCycleType
    let id: UInt64

    var lastScheduledTime: UInt64?
    var hasPendingInstance: Bool = false

    init(
        task: @escaping () -> Void,
        priority: Int = 0,
        startTime: UInt64,
        period: UInt64,
        repeatType: RepeatCycleType = .relative,
        id: UInt64 = 0
    ) {
        self.task = task
        self.priority = Int8(priority)
        self.startTime = startTime
        self.period = period
        self.repeatType = repeatType
        self.id = id
        self.lastScheduledTime = nil
    }
}

class FSScheduler {
    enum TaskExecutionResult {
        case success, noTasks, failure, timeout
    }
    
    var fstime: FSTime
    
    var instantTasks: [FSSchedulerInstantTask]
    var instantTaskPriorities: [Int8]
    var timedTasks: [FSSchedulerTimedTask]
    var timedTasksPriorities: [Int8]
    var timedTasksExecutionTimes: [UInt64]
    var repeativeTasks: [FSSchedulerRepeativeTask]
    
    var nextWakeup: UInt64
    
    private func getBudgetInsertionIndex(
        priorities: [Int8],
        newPriority: Int8
    ) -> Int {
        if priorities.isEmpty {
            return 0
        }
        
        if newPriority <= 0 {
            return priorities.count
        }
        
        var samePriorityCount = 0
        
        for (index, existingPriority) in priorities.enumerated() {
            if existingPriority == 0 {
                return index
            }
            
            if existingPriority < newPriority {
                return index
            }
            
            if existingPriority == newPriority {
                samePriorityCount += 1
                if samePriorityCount >= Int(newPriority) {
                    return index + 1
                }
            } else {
                samePriorityCount = 0
            }
        }
        
        return priorities.count
    }
    
    private func lowerBoundExecutionTime(_ executionTime: UInt64) -> Int {
        var low = 0
        var high = self.timedTasksExecutionTimes.count
        
        while low < high {
            let mid = (low + high) / 2
            if self.timedTasksExecutionTimes[mid] < executionTime {
                low = mid + 1
            } else {
                high = mid
            }
        }
        
        return low
    }
    
    private func upperBoundExecutionTime(_ executionTime: UInt64) -> Int {
        var low = 0
        var high = self.timedTasksExecutionTimes.count
        
        while low < high {
            let mid = (low + high) / 2
            if self.timedTasksExecutionTimes[mid] <= executionTime {
                low = mid + 1
            } else {
                high = mid
            }
        }
        
        return low
    }
    
    func addInstantTask(_ task: FSSchedulerInstantTask) {
        let index = self.getBudgetInsertionIndex(
            priorities: self.instantTaskPriorities,
            newPriority: task.priority
        )
        
        self.instantTasks.insert(task, at: index)
        self.instantTaskPriorities.insert(task.priority, at: index)
    }
    
    func addDeferredTask(_ task: FSSchedulerDeferredTask) {
        let timed = FSSchedulerTimedTask(
        task: task.task,
        priority: Int(task.priority),
        executionTime: task.executionTime,
        id: task.id,
        sourceType: .deferred
        )
        self.insertTimedTask(timed)
    }
    
    func addRepeativeTask(_ task: FSSchedulerRepeativeTask) {
        self.repeativeTasks.append(task)
        self.fillRepeativeTask(task)
    }
    
    private func insertTimedTask(_ task: FSSchedulerTimedTask) {
        let startIndex = self.lowerBoundExecutionTime(task.executionTime)
        let endIndex = self.upperBoundExecutionTime(task.executionTime)

        let insertionIndex: Int
        if startIndex == endIndex {
            insertionIndex = startIndex
        } else {
            let sameTimePriorities = Array(self.timedTasksPriorities[startIndex..<endIndex])
            let budgetIndex = self.getBudgetInsertionIndex(
                priorities: sameTimePriorities,
                newPriority: task.priority
            )
            insertionIndex = startIndex + budgetIndex
        }

        self.timedTasks.insert(task, at: insertionIndex)
        self.timedTasksPriorities.insert(task.priority, at: insertionIndex)
        self.timedTasksExecutionTimes.insert(task.executionTime, at: insertionIndex)
        self.nextWakeup = self.timedTasksExecutionTimes.first ?? 0
    }

    private func fillRepeativeTask(_ task: FSSchedulerRepeativeTask) {
        let now = self.fstime.getms()
        let limit = now + 2000

        switch task.repeatType {
        case .absolute:
            var nextTime: UInt64

            if let last = task.lastScheduledTime {
                nextTime = last + task.period
            } else if task.startTime >= now {
                nextTime = task.startTime
            } else {
                let delta = now - task.startTime
                let steps = delta / task.period
                nextTime = task.startTime + steps * task.period
                if nextTime < now {
                    nextTime += task.period
                }
            }

            while nextTime <= limit {
                let timed = FSSchedulerTimedTask(
                    task: task.task,
                    priority: Int(task.priority),
                    executionTime: nextTime,
                    id: task.id,
                    sourceType: .repeative(parentId: task.id)
                )
                self.insertTimedTask(timed)
                task.lastScheduledTime = nextTime
                nextTime += task.period
            }

        case .relative:
            if task.hasPendingInstance {
                return
            }

            let nextTime: UInt64
            if let last = task.lastScheduledTime {
                nextTime = last + task.period
            } else {
                nextTime = max(task.startTime, now)
            }

            guard nextTime <= limit else { return }

            let timed = FSSchedulerTimedTask(
                task: task.task,
                priority: Int(task.priority),
                executionTime: nextTime,
                id: task.id,
                sourceType: .repeative(parentId: task.id)
            )
            self.insertTimedTask(timed)
            task.lastScheduledTime = nextTime
            task.hasPendingInstance = true
        }
    }
    
    func step() -> FSScheduler.TaskExecutionResult {
        let cs = self.fstime.getms()
        if cs >= self.nextWakeup && !self.timedTasks.isEmpty {
            let task = self.timedTasks[0]
            task.task()
            let priority = self.timedTasksPriorities[0]
            self.timedTasks.removeFirst()
            self.timedTasksPriorities.removeFirst()
            self.timedTasksExecutionTimes.removeFirst()
            self.nextWakeup = self.timedTasksExecutionTimes.first ?? 0
            if case let .repeative(parentId) = task.sourceType,
                    let repeatTask = self.repeativeTasks.first(where: { $0.id == parentId }) {
                self.fillRepeativeTask(repeatTask)
            }


            
            return .success
        }
        if !self.instantTasks.isEmpty {
            let task = self.instantTasks[0]
            task.task()
            self.instantTasks.removeFirst()
            self.instantTaskPriorities.removeFirst()
            return .success
        }
        return .failure
    }
    
    init(
        fstime: FSTime = FSTime(getms: {return 0})
    ) {
        self.fstime = fstime
        
        self.instantTasks = []
        self.instantTaskPriorities = []
        self.timedTasks = []
        self.timedTasksPriorities = []
        self.timedTasksExecutionTimes = []
        self.repeativeTasks = []
        self.nextWakeup = 0

    }
}
