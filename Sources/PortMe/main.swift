import Foundation
import PortMeKit

let arguments = Array(CommandLine.arguments.dropFirst())

if let index = arguments.firstIndex(of: "--demo-shot"), arguments.count > index + 1 {
    MainActor.assumeIsolated { DemoShot.capture(to: arguments[index + 1]) }
} else if arguments.contains("--version") {
    print("Port me \(AppVersion.display)")
} else if arguments.contains("--list") {
    PortMeCLI.printList(showAll: arguments.contains("--all"))
} else {
    PortMeApp.run()
}
