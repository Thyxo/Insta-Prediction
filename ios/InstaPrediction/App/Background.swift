// Holder appen i live i baggrunden med lydløs lyd (UIBackgroundModes: audio).
// Nødvendigt når input kommer fra en anden app på samme telefon (fx Fake Google i Safari):
// ellers sætter iOS appen på pause, og relæet + bio-kaldet når aldrig frem.
// Blander sig med anden lyd (.mixWithOthers), så musik ikke stopper.
import AVFoundation
import UserNotifications

@MainActor
final class BackgroundKeeper {
    private var engine: AVAudioEngine?

    var running: Bool { engine?.isRunning == true }

    func start() {
        guard engine == nil else { return }
        do {
            let s = AVAudioSession.sharedInstance()
            try s.setCategory(.playback, options: [.mixWithOthers])
            try s.setActive(true)
            let e = AVAudioEngine()
            guard let fmt = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1) else { return }
            let silence = Self.silenceNode()
            e.attach(silence)
            e.connect(silence, to: e.mainMixerNode, format: fmt)
            e.mainMixerNode.outputVolume = 0
            try e.start()
            engine = e
        } catch {
            engine = nil
        }
    }

    /// Lydkæden kalder blokken på en lyd-tråd, ikke main; derfor nonisolated.
    nonisolated private static func silenceNode() -> AVAudioSourceNode {
        AVAudioSourceNode { _, _, _, abl in
            for b in UnsafeMutableAudioBufferListPointer(abl) {
                if let p = b.mData { memset(p, 0, Int(b.mDataByteSize)) }
            }
            return noErr
        }
    }

    func stop() {
        engine?.stop()
        engine = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
    }
}

/// Diskrete notifikationer (ses på låseskærmen og på Apple Watch, når telefonen er låst)
enum Notifier {
    static func ask() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    static func post(_ title: String, _ body: String) {
        let c = UNMutableNotificationContent()
        c.title = title
        c.body = body
        let r = UNNotificationRequest(identifier: UUID().uuidString, content: c, trigger: nil)
        UNUserNotificationCenter.current().add(r)
    }
}
