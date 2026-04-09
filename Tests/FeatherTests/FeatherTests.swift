import Testing
@testable import Feather

@Test
func fstimeUpdatesCurrentMillisecondsFromProvider() {
    var now: UInt64 = 12
    let time = FSTime(getms: { now })

    #expect(time.currentms == 0)
    #expect(time.getms() == 12)
    #expect(time.currentms == 12)

    now = 34
    #expect(time.getms() == 34)
    #expect(time.currentms == 34)
}

@Test
func timedTasksRunInExecutionOrder() {
    var currentTime: UInt64 = 0
    let scheduler = FSScheduler(fstime: FSTime(getms: { currentTime }))
    var executed: [String] = []

    scheduler.addTimedTask(
        FSSchedulerTimedTask(task: { executed.append("later") }, executionTime: 20)
    )
    scheduler.addTimedTask(
        FSSchedulerTimedTask(task: { executed.append("sooner") }, executionTime: 10)
    )

    currentTime = 10
    #expect(scheduler.step() == .success)
    #expect(executed == ["sooner"])

    currentTime = 15
    #expect(scheduler.step() == .failure)
    #expect(executed == ["sooner"])

    currentTime = 20
    #expect(scheduler.step() == .success)
    #expect(executed == ["sooner", "later"])
}

@Test
func instantTasksRunWhenNoTimedTaskIsReady() {
    var currentTime: UInt64 = 5
    let scheduler = FSScheduler(fstime: FSTime(getms: { currentTime }))
    var executed: [String] = []

    scheduler.addTimedTask(
        FSSchedulerTimedTask(task: { executed.append("timed") }, executionTime: 10)
    )
    scheduler.addInstantTask(
        FSSchedulerInstantTask(task: { executed.append("instant") })
    )

    #expect(scheduler.step() == .success)
    #expect(executed == ["instant"])

    currentTime = 10
    #expect(scheduler.step() == .success)
    #expect(executed == ["instant", "timed"])
}

@Test
func relativeRepeativeTasksStayScheduledAfterFirstRun() {
    var currentTime: UInt64 = 0
    let scheduler = FSScheduler(fstime: FSTime(getms: { currentTime }))
    var executed: [UInt64] = []

    scheduler.addRepeativeTask(
        FSSchedulerRepeativeTask(
            task: { executed.append(currentTime) },
            startTime: 0,
            period: 3_000,
            repeatType: .relative,
            id: 1
        )
    )

    #expect(scheduler.nextWakeup == 0)
    #expect(scheduler.step() == .success)
    #expect(executed == [0])
    #expect(scheduler.nextWakeup == 3_000)

    currentTime = 2_999
    #expect(scheduler.step() == .failure)
    #expect(executed == [0])

    currentTime = 3_000
    #expect(scheduler.step() == .success)
    #expect(executed == [0, 3_000])
}

@Test
func absoluteRepeativeTasksKeepNextFutureWakeup() {
    var currentTime: UInt64 = 0
    let scheduler = FSScheduler(fstime: FSTime(getms: { currentTime }))
    var executed: [UInt64] = []

    scheduler.addRepeativeTask(
        FSSchedulerRepeativeTask(
            task: { executed.append(currentTime) },
            startTime: 0,
            period: 5_000,
            repeatType: .absolute,
            id: 2
        )
    )

    #expect(scheduler.nextWakeup == 0)
    #expect(scheduler.step() == .success)
    #expect(executed == [0])
    #expect(scheduler.nextWakeup == 5_000)

    currentTime = 5_000
    #expect(scheduler.step() == .success)
    #expect(executed == [0, 5_000])
}
