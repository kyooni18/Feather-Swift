class Feather {
    var scheduler: FSScheduler
    var time: FSTime
    init(
        getmsFunc: @escaping () -> UInt64 = { return 0 }
    ) {
        self.scheduler = FSScheduler()
        self.time = FSTime(getms: getmsFunc)
    }
}
