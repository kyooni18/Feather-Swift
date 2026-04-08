class FSTime {
    var currentms: UInt64
    private let getmsProvider: () -> UInt64
    var getms: () -> UInt64 {
        {
            let currentms = self.getmsProvider()
            self.currentms = currentms
            return currentms
        }
    }
    
    init(
        getms: @escaping () -> UInt64
    ) {
        self.currentms = 0
        self.getmsProvider = getms
    }
}
