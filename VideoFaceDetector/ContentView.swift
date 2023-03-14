import SwiftUI
import AVKit
import Vision

struct ContentView: View {
    @StateObject var viewModel = VideoViewModel()
    
    var body: some View {
        VStack {
            VideoPlayer(player: viewModel.player)
                .frame(height: 400)
                .onAppear {
                    viewModel.startPlayback()
                }
        }
        .onReceive(viewModel.faceObservations) { faceObservations in
            viewModel.drawFaces(on: faceObservations)
        }
    }
}

class VideoViewModel: ObservableObject {
    @Published var player: AVPlayer = AVPlayer()
    @Published var faceObservations: [VNFaceObservation] = []
    
    private var videoPlayer: AVPlayer?
    private var videoPlayerLayer: AVPlayerLayer?
    private var faceDetectionRequest: VNRequest?
    
    func startPlayback() {
        guard let url = Bundle.main.url(forResource: "example", withExtension: "mp4") else { return }
        
        let asset = AVAsset(url: url)
        let playerItem = AVPlayerItem(asset: asset)
        videoPlayer = AVPlayer(playerItem: playerItem)
        
        videoPlayerLayer = AVPlayerLayer(player: videoPlayer)
        videoPlayerLayer?.frame = CGRect(x: 0, y: 0, width: 640, height: 480)
        
        player = videoPlayer!
        
        faceDetectionRequest = VNDetectFaceRectanglesRequest(completionHandler: handleFaces)
        
        let videoOutput = AVPlayerItemVideoOutput(pixelBufferAttributes: nil)
        playerItem.add(videoOutput)
        
        let queue = DispatchQueue(label: "com.example.vision.face-detection")
        playerItem.videoComposition = AVVideoComposition(
            asset: asset,
            applyingCIFiltersWithHandler: { request in
                queue.async {
                    guard let buffer = videoOutput.copyPixelBuffer(forItemTime: request.compositionTime, itemTimeForDisplay: nil) else { return }
                    let image = CIImage(cvPixelBuffer: buffer)
                    self.performFaceDetection(on: image)
                }
            }
        )
        
        player.play()
    }
    
    func performFaceDetection(on image: CIImage) {
        let handler = VNImageRequestHandler(ciImage: image, options: [:])
        do {
            try handler.perform([faceDetectionRequest!])
        } catch {
            print(error)
        }
    }
    
    func handleFaces(request: VNRequest, error: Error?) {
        guard let observations = request.results as? [VNFaceObservation] else { return }
        
        DispatchQueue.main.async {
            self.faceObservations = observations
        }
    }
    
    func drawFaces(on faceObservations: [VNFaceObservation]) {
        guard let playerLayer = videoPlayerLayer else { return }
        
        let sublayers = playerLayer.sublayers ?? []
        for layer in sublayers {
            layer.removeFromSuperlayer()
        }
        
        for faceObservation in faceObservations {
            let faceRectangle = faceObservation.boundingBox
            let width = playerLayer.frame.width * faceRectangle.width
            let height = playerLayer.frame.height * faceRectangle.height
            let x = playerLayer.frame.width * faceRectangle.origin.x
            let y = playerLayer.frame.height * (1 - faceRectangle.origin.y) - height
            
            let faceLayer = CALayer()
            faceLayer.frame = CGRect(x: x, y: y, width: width, height: height)
            faceLayer.borderWidth = 2
            faceLayer.borderColor = CGColor(red: 1, green: 0, blue: 0, alpha: 1)
            playerLayer.addSublayer(faceLayer)
        }
    }
}
