class Feather {
    var scheduler: FSScheduler
    var time: FSTime
    
    init(
        getmsFunc: @escaping () -> UInt64 = { 0 }
    ) {
        self.time = FSTime(getms: getmsFunc)
        self.scheduler = FSScheduler(fstime: self.time)
    }
}
