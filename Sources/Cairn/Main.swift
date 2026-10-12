import SwiftUI

@main
struct CairnMain {
    static func main() {
        #if os(macOS)
        MacMain.run()
        #else
        PhoneApp.main()
        #endif
    }
}
