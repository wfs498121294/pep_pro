import SwiftUI
import AVFoundation

struct ExerciseDetailView: View {
    let exercise: Exercise
    
    @State private var isExerciseActive = false
    @State private var remainingTime: TimeInterval = 0
    @State private var timer: Timer? = nil
    @State private var showingVideoRecorder = false
    @State private var showingModifySheet = false
    
    // Exercise modification fields
    @State private var modifiedFrequency = "daily"
    @State private var modifiedSets = 3
    @State private var modifiedReps = 10
    @State private var modifiedNotes = ""
    @State private var recordedVideoURL: URL? = nil
    
    // API connection states
    @State private var isUploading = false
    @State private var uploadError: String? = nil
    
    // Required environment objects
    @EnvironmentObject var cameraManager: CameraManager
    @EnvironmentObject var visionManager: VisionManager
    @EnvironmentObject var voiceManager: VoiceManager
    @EnvironmentObject var speechRecognitionManager: SpeechRecognitionManager
    @EnvironmentObject var resourceCoordinator: ResourceCoordinator
    
    var body: some View {
        ZStack {
            exerciseContent
        }
        .navigationBarTitle("", displayMode: .inline)
        .navigationBarItems(trailing: isExerciseActive ? nil : Button(action: {
            // Info button action
        }) {
            Image(systemName: "info.circle")
        })
        .onDisappear {
            if isExerciseActive {
                stopExercise()
            }
        }
        .sheet(isPresented: $showingModifySheet) {
            ModifyExerciseView(
                exercise: exercise,
                frequency: $modifiedFrequency,
                sets: $modifiedSets,
                reps: $modifiedReps,
                notes: $modifiedNotes,
                onSave: saveModifications
            )
            .environmentObject(voiceManager)
            .environmentObject(speechRecognitionManager)
            .environmentObject(resourceCoordinator)
            .environmentObject(cameraManager)
            .environmentObject(visionManager)
        }
        .sheet(isPresented: $showingVideoRecorder) {
            ExerciseVideoRecorder(onVideoSaved: { url in
                self.recordedVideoURL = url
                saveModifications()
            })
            .environmentObject(cameraManager)
            .environmentObject(visionManager)
            .environmentObject(voiceManager)
            .environmentObject(speechRecognitionManager)
            .environmentObject(resourceCoordinator)
        }
        .overlay(
            Group {
                if isUploading {
                    VStack {
                        ProgressView()
                        Text("Saving changes...")
                            .font(.caption)
                            .padding(.top, 8)
                    }
                    .frame(width: 150, height: 100)
                    .background(Color.black.opacity(0.7))
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
            }
        )
    }
    
    // Split the content into a computed property to reduce complexity
    private var exerciseContent: some View {
        Group {
            if isExerciseActive {
                activeExerciseView
            } else {
                exerciseDetailsView
            }
        }
    }
    
    // Active exercise view with camera feed and pose detection
    private var activeExerciseView: some View {
        ZStack {
            // Camera view
            CameraPreview(session: cameraManager.session)
                .edgesIgnoringSafeArea(.all)
            
            // Body pose overlay
            BodyPoseView(bodyPose: visionManager.currentBodyPose)
                .edgesIgnoringSafeArea(.all)
            
            // Timer and controls overlay
            VStack {
                Spacer()
                
                // Timer display
                Text(timeString(from: remainingTime))
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.black.opacity(0.5))
                    .cornerRadius(16)
                
                Spacer()
                
                // Stop button
                Button(action: {
                    stopExercise()
                }) {
                    HStack {
                        Image(systemName: "stop.fill")
                        Text("Stop Exercise")
                    }
                    .padding()
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .padding(.bottom, 32)
            }
        }
    }
    
    // Exercise details view when not active
    private var exerciseDetailsView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header with image
                exerciseImageView
                
                // Exercise title and description
                Text(exercise.name)
                    .font(.title)
                    .fontWeight(.bold)
                
                Text(exercise.description)
                    .foregroundColor(.secondary)
                
                // Modification controls
                modificationControlsView
                
                // Target joints
                targetJointsView
                
                // Instructions
                instructionsView
                
                // Start button
                Button(action: {
                    startExercise()
                }) {
                    Text("Start Exercise")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                }
                .padding(.top, 16)
            }
            .padding()
        }
    }
    
    // Exercise image view
    private var exerciseImageView: some View {
        Group {
            if let imageURL = exercise.imageURL {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .empty:
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .aspectRatio(16/9, contentMode: .fit)
                            .overlay(ProgressView())
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(16/9, contentMode: .fit)
                    case .failure:
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .aspectRatio(16/9, contentMode: .fit)
                            .overlay(
                                Image(systemName: "photo")
                                    .font(.largeTitle)
                            )
                    @unknown default:
                        EmptyView()
                    }
                }
                .cornerRadius(12)
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .aspectRatio(16/9, contentMode: .fit)
                    .overlay(
                        Image(systemName: "photo")
                            .font(.largeTitle)
                    )
                    .cornerRadius(12)
            }
        }
    }
    
    // Modification controls view
    private var modificationControlsView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()
            
            Text("Customize Exercise")
                .font(.headline)
                .foregroundColor(.blue)
            
            Button(action: {
                showingModifySheet = true
            }) {
                HStack {
                    Image(systemName: "pencil")
                    Text("Modify Exercise")
                }
                .padding(10)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
            }
            
            Button(action: {
                showingVideoRecorder = true
            }) {
                HStack {
                    Image(systemName: "video.fill")
                    Text("Record Custom Video")
                }
                .padding(10)
                .background(Color.green.opacity(0.1))
                .cornerRadius(8)
            }
            
            if let error = uploadError {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
            }
            
            Divider()
        }
    }
    
    // Target joints view
    private var targetJointsView: some View {
        VStack(alignment: .leading) {
            Text("Target Areas")
                .font(.headline)
            
            HStack {
                ForEach(exercise.targetJoints, id: \.self) { joint in
                    Text(joint.rawValue)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.blue.opacity(0.2))
                        .cornerRadius(8)
                }
            }
        }
    }
    
    // Instructions view
    private var instructionsView: some View {
        VStack(alignment: .leading) {
            Text("Instructions")
                .font(.headline)
            
            ForEach(Array(exercise.instructions.enumerated()), id: \.offset) { index, instruction in
                HStack(alignment: .top) {
                    Text("\(index + 1).")
                        .fontWeight(.bold)
                    Text(instruction)
                }
                .padding(.vertical, 4)
            }
        }
    }
    
    // Start exercise function
    private func startExercise() {
        // Begin coordinating resources
        resourceCoordinator.printAudioRouteInfo() // Check what audio devices are connected
        resourceCoordinator.testMicrophoneInput() // Test if mic is receiving audio
        resourceCoordinator.startExerciseSession { success in
            guard success else { return }
            
            // Start camera and vision processing
            cameraManager.startSession()
            visionManager.startProcessing(cameraManager.videoOutput)
            
            // Start voice assistant
            voiceManager.startElevenLabsSession()
            
            // Start speech recognition
            speechRecognitionManager.startListening()
            
            // Setup timer
            remainingTime = exercise.duration
            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
                if remainingTime > 0 {
                    remainingTime -= 1
                } else {
                    stopExercise()
                }
            }
            
            // Update UI
            isExerciseActive = true
        }
    }
    
    // Stop exercise function
    private func stopExercise() {
        // Stop timer
        timer?.invalidate()
        timer = nil
        
        // Stop coordinating resources
        resourceCoordinator.stopExerciseSession()
        
        // Update UI
        isExerciseActive = false
    }
    
    // Format time string
    private func timeString(from timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    // Save modifications function
    private func saveModifications() {
        // Show loading indicator
        isUploading = true
        uploadError = nil
        
        // Prepare video data if available
        var videoData: Data? = nil
        if let recordedVideoURL = self.recordedVideoURL {
            do {
                videoData = try Data(contentsOf: recordedVideoURL)
            } catch {
                self.uploadError = "Failed to read video data: \(error.localizedDescription)"
                self.isUploading = false
                return
            }
        }
        
        // Construct the request body
        var requestBody: [String: Any] = [
            "action": "modify",
            "user_id": UserDefaults.standard.string(forKey: "user_id") ?? UUID().uuidString,
            "patient_id": UserDefaults.standard.string(forKey: "patient_id") ?? UUID().uuidString,
            "patient_exercise_id": exercise.id.uuidString,
            "modifications": [
                "frequency": self.modifiedFrequency,
                "sets": self.modifiedSets,
                "repetitions": self.modifiedReps,
                "notes": self.modifiedNotes
            ]
        ]
        
        // Add video data if available
        if let videoData = videoData {
            requestBody["custom_video"] = [
                "base64_data": videoData.base64EncodedString(),
                "content_type": "video/mp4",
                "filename": "\(exercise.id)-custom.mp4"
            ]
        }
        
        // Convert request body to JSON
        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) else {
            self.uploadError = "Failed to create request data"
            self.isUploading = false
            return
        }
        
        // Create the URL request
        let urlString = "https://us-central1-duoligo-pt-app.cloudfunctions.net/manage_exercise"
        guard let url = URL(string: urlString) else {
            self.uploadError = "Invalid API URL"
            self.isUploading = false
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        
        // Create the data task
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.isUploading = false
                
                if let error = error {
                    self.uploadError = "Network error: \(error.localizedDescription)"
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    self.uploadError = "Invalid response from server"
                    return
                }
                
                if httpResponse.statusCode != 200 {
                    self.uploadError = "Server error: HTTP \(httpResponse.statusCode)"
                    if let data = data, let errorMessage = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let errorText = errorMessage["error"] as? String {
                        self.uploadError = errorText
                    }
                    return
                }
                
                guard let data = data else {
                    self.uploadError = "No data received from server"
                    return
                }
                
                // Parse the response
                do {
                    let responseDict = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                    
                    if let status = responseDict?["status"] as? String, status == "success" {
                        // Handle success - perhaps update the local exercise data
                        if let exerciseData = responseDict?["exercise"] as? [String: Any],
                           let videoUrl = exerciseData["video_url"] as? String {
                            // Update URL if a new video was saved
                            // In a real app, you'd update the actual Exercise object or reload it
                            print("Exercise updated with new video URL: \(videoUrl)")
                        }
                        
                        // Display success feedback
                        // You could use a toast message or other UI indicator here
                        self.uploadError = nil
                    } else {
                        self.uploadError = responseDict?["error"] as? String ?? "Unknown error"
                    }
                } catch {
                    self.uploadError = "Failed to parse response: \(error.localizedDescription)"
                }
            }
        }
        
        // Start the request
        task.resume()
    }
}

// Camera preview for AVCaptureSession
struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: UIScreen.main.bounds)
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.frame = view.frame
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {}
}
