import Foundation
import PortMeKit

let arguments = Array(CommandLine.arguments.dropFirst())

if arguments.contains("--version") {
    print("Port me \(AppVersion.display)")
} else if arguments.contains("--list") {
    PortMeCLI.printList(showAll: arguments.contains("--all"))
} else {
    PortMeApp.run()
}
