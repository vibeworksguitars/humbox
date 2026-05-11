import SoundAnalysis
import CoreMedia

// Uses Apple's built-in SNClassifySoundRequest (AudioSet ontology, ~300 categories)
// to classify a recorded audio file into one of Humbox's content types.
// analyze() is synchronous — always call from a background Task.
final class ContentClassifier: NSObject, SNResultsObserving {

    private var votes: [String: Double] = [:]

    static func classify(audioFileURL: URL) -> Memo.ContentType {
        let instance = ContentClassifier()
        do {
            let request = try SNClassifySoundRequest(classifierIdentifier: .version1)
            // 1.5-second windows with 50% overlap gives good coverage on short clips
            request.windowDuration = CMTimeMakeWithSeconds(1.5, preferredTimescale: 44100)
            request.overlapFactor = 0.5
            let analyzer = try SNAudioFileAnalyzer(url: audioFileURL)
            try analyzer.add(request, withObserver: instance)
            analyzer.analyze()
        } catch {
            print("ContentClassifier error: \(error)")
        }
        return instance.topContentType()
    }

    // MARK: - SNResultsObserving

    func request(_ request: SNRequest, didProduce result: SNResult) {
        guard let result = result as? SNClassificationResult else { return }
        // Accumulate confidence scores across all windows
        for classification in result.classifications.prefix(5) {
            votes[classification.identifier, default: 0] += classification.confidence
        }
    }

    func request(_ request: SNRequest, didFailWithError error: Error) {
        print("ContentClassifier window error: \(error)")
    }

    func requestDidComplete(_ request: SNRequest) {}

    // MARK: - Mapping

    private func topContentType() -> Memo.ContentType {
        guard !votes.isEmpty else { return .unknown }

        // Bucket the raw AudioSet labels into our 7 content types
        var scores: [Memo.ContentType: Double] = [:]
        for (label, score) in votes {
            let l = label.lowercased()
            if l.contains("guitar") || l.contains("banjo") || l.contains("ukulele") {
                scores[.guitar, default: 0] += score
            } else if l.contains("piano") || l.contains("keyboard") || l.contains("organ") {
                scores[.piano, default: 0] += score
            } else if l.contains("drum") || l.contains("percussion") || l.contains("beat") || l.contains("snare") || l.contains("hi-hat") {
                scores[.percussion, default: 0] += score
            } else if l.contains("speech") || l.contains("talking") || l.contains("rap") || l.contains("spoken") {
                scores[.lyrics, default: 0] += score
            } else if l.contains("singing") || l.contains("humming") || l.contains("vocal") || l.contains("choir") {
                scores[.humming, default: 0] += score
            } else if l.contains("music") || l.contains("melody") || l.contains("instrument") {
                scores[.mixed, default: 0] += score
            }
        }

        return scores.max(by: { $0.value < $1.value })?.key ?? .unknown
    }
}
