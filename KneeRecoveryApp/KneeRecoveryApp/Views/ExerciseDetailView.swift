import SwiftUI
import AVFoundation

struct ExerciseDetailView: View {
    let exercise: Exercise
    
    // State variables
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
    
    // Exercise report states
    @State private var showingExerciseReport = false
    @State private var exerciseDuration: TimeInterval = 0
    
    // API connection states
    @State private var isUploading = false
    @State private var uploadError: String? = nil
    
    // Coach state
    @State private var coachMessages: [String] = []
    @State private var showCoachFeedback = false
    
    // Operation tracking flags
    @State private var isStartingExercise = false
    @State private var isStoppingExercise = false
    @State private var isTransitioning = false
    
    // Environment objects
    @EnvironmentObject private var cameraManager: CameraManager
    @EnvironmentObject private var visionManager: VisionManager
    @EnvironmentObject private var voiceManager: VoiceManager
    @EnvironmentObject private var speechRecognitionManager: SpeechRecognitionManager
    @EnvironmentObject private var resourceCoordinator: ResourceCoordinator
    
    var body: some View {
        ZStack {
            // Camera feed with body pose visualization overlay when exercise is active
            if isExerciseActive {
                ZStack {
                    // Camera view
                    CameraPreview(session: cameraManager.session)
                        .edgesIgnoringSafeArea(.all)
                    
                    // Body pose overlay
                    BodyPoseView(bodyPose: visionManager.currentBodyPose)
                        .edgesIgnoringSafeArea(.all)
                    
                    // Coach message bubble if there are messages
                    if !coachMessages.isEmpty, showCoachFeedback {
                        VStack {
                            Text(coachMessages.last ?? "")
                                .padding()
                                .background(Color.white.opacity(0.8))
                                .foregroundColor(.black)
                                .cornerRadius(12)
                                .padding(.horizontal)
                                .padding(.top, 40)
                            
                            Spacer()
                        }
                    }
                    
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
                        .disabled(isStoppingExercise)
                    }
                }
            } else {
                // Exercise details and start button when not active
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Header with image
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
                        }
                        
                        // Exercise title and description
                        Text(exercise.name)
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text(exercise.description)
                            .foregroundColor(.secondary)
                        
                        // Modification controls - available for all users
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
                        
                        // Target joints
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
                        
                        // Instructions
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
                        
                        // Start button
                        Button(action: {
                            startExercise()
                        }) {
                            Text("Start Exercise")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(isStartingExercise ? Color.gray : Color.blue)
                                .cornerRadius(12)
                        }
                        .padding(.top, 16)
                        .disabled(isStartingExercise)
                    }
                    .padding()
                }
            }
            
            // Loading overlay when starting exercise
            if isStartingExercise {
                Color.black.opacity(0.7)
                    .edgesIgnoringSafeArea(.all)
                    .overlay(
                        VStack {
                            ProgressView()
                                .scaleEffect(1.5)
                                .tint(.white)
                            
                            Text("Setting up exercise...")
                                .foregroundColor(.white)
                                .padding(.top, 20)
                        }
                    )
            }
        }
        .navigationBarTitle("", displayMode: .inline)
        .navigationBarItems(trailing: isExerciseActive ? nil : Button(action: {
            // Info button action
        }) {
            Image(systemName: "info.circle")
        })
        .onDisappear {
            // Ensure session cleanup when navigating away
            if isExerciseActive || isStartingExercise {
                // Stop any active timers
                timer?.invalidate()
                timer = nil
                
                // Forcefully clear any active ElevenLabs sessions
                voiceManager.endElevenLabsSession()
                
                // Clear camera resources
                cameraManager.stopSession()
                visionManager.stopProcessing()
                
                // Reset states
                isExerciseActive = false
                isStartingExercise = false
                isStoppingExercise = false
            }
            
            // Additional cleanup
            speechRecognitionManager.stopListening()
            
            // Always deactivate audio session when leaving the view
            do {
                try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            } catch {
                print("Error deactivating audio session: \(error)")
            }
            
            // Clean up notification observer
            removeExerciseCoachObserver()
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
        }
        .sheet(isPresented: $showingVideoRecorder) {
            ExerciseVideoRecorder(onVideoSaved: { url in
                self.recordedVideoURL = url
                saveModifications()
            })
        }
        // Use fullScreenCover for the report instead of sheet for better presentation
        .fullScreenCover(isPresented: $showingExerciseReport) {
            NavigationView {
                ExerciseReportView(
                    exercise: exercise,
                    duration: exerciseDuration,
                    date: Date()
                )
                .environmentObject(voiceManager)
                .navigationBarItems(trailing: Button("Done") {
                    showingExerciseReport = false
                })
            }
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
        .onAppear {
            // Set up exercise coach notification observer
            setupExerciseCoachObserver()
        }
    }
    
    // Set up notification observer for the exercise coach
    private func setupExerciseCoachObserver() {
        NotificationCenter.default.addObserver(
            forName: Notification.Name("ExerciseFeedback"),
            object: nil,
            queue: .main
        ) { notification in
            guard let message = notification.userInfo?["message"] as? String else { return }
            
            // Add message to the coach messages
            coachMessages.append(message)
            
            // Show the feedback
            showCoachFeedback = true
            
            // Auto-hide after a delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                if isExerciseActive {
                    showCoachFeedback = false
                }
            }
        }
    }
    
    // Remove notification observer
    private func removeExerciseCoachObserver() {
        NotificationCenter.default.removeObserver(
            self,
            name: Notification.Name("ExerciseFeedback"),
            object: nil
        )
    }
    
    private func startExercise() {
        // Prevent multiple starts or starts during transitions
        guard !isExerciseActive && !isTransitioning else {
            print("⚠️ Exercise already active or transitioning - ignoring start request")
            return
        }
        
        // Set transitioning flag
        isTransitioning = true
        
        // Prevent multiple starts
        if isStartingExercise {
            return
        }
        
        // Begin coordinating resources
        resourceCoordinator.printAudioRouteInfo()
        
        // Begin by disabling UI
        isStartingExercise = true
        
        // Important: Always end any prior sessions first with a completion handler
        voiceManager.endElevenLabsSession {
            // Start the exercise session after ensuring the previous session is ended
            resourceCoordinator.startExerciseSession { success in
                guard success else {
                    DispatchQueue.main.async {
                        isStartingExercise = false
                    }
                    return
                }
                
//                // Start camera and vision processing
//                cameraManager.startSession()
//                visionManager.startProcessing(cameraManager.videoOutput)
                
                // Start the exercise coach agent with a completion handler
                voiceManager.startExerciseCoachAgent {
                    DispatchQueue.main.async {
                        // Setup timer only after the session is started
                        remainingTime = exercise.duration
                        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
                            if remainingTime > 0 {
                                remainingTime -= 1
                            } else {
                                stopExercise()
                            }
                        }
                        
                        // Initialize coach messages
                        coachMessages = ["I'll help guide you through this exercise. Let me see your form..."]
                        showCoachFeedback = true
                        
                        // Auto-hide initial message after a few seconds
                        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                            if isExerciseActive {
                                showCoachFeedback = false
                            }
                        }
                        
                        // Update UI after everything is ready
                        isExerciseActive = true
                        isStartingExercise = false
                    }
                }
            }
        }
    }
    
    private func stopExercise() {
        // Set state to prevent multiple calls
        if isStoppingExercise {
            return
        }
        
        isStoppingExercise = true
        
        // Stop timer
        timer?.invalidate()
        timer = nil
        
        let actualDuration = exercise.duration - remainingTime
        exerciseDuration = actualDuration
        
        // End the exercise coach session first
        voiceManager.endElevenLabsSession {
            // Then stop coordinating resources
            resourceCoordinator.stopExerciseSession {
                // Clear coach messages
                coachMessages = []
                
                // Update UI
                DispatchQueue.main.async {
                    isExerciseActive = false
                    isStoppingExercise = false
                    
                    // Show exercise report - use a slight delay to ensure previous UI updates complete
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showingExerciseReport = true
                    }
                }
            }
        }
    }
    
    private func timeString(from timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
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
            "pt_id": "pt-uuid", // Replace with actual PT ID or fetch from UserDefaults
            "patient_id": UserDefaults.standard.string(forKey: "PatientID") ?? UUID().uuidString,
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
        let urlString = "https://us-central1-pep-pro.cloudfunctions.net/modify_exercise"
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
                    print("Network error: \(error.localizedDescription)")
                    self.uploadError = "Network error: \(error.localizedDescription)"
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    self.uploadError = "Invalid response from server"
                    return
                }
                
                guard let data = data else {
                    self.uploadError = "No data received from server"
                    return
                }
                
                if httpResponse.statusCode != 200 {
                    self.uploadError = "Server error: HTTP \(httpResponse.statusCode)"
                    if let errorMessage = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let errorText = errorMessage["error"] as? String {
                        self.uploadError = errorText
                    }
                    return
                }
                
                // Parse the response
                do {
                    let responseDict = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                    
                    if let status = responseDict?["status"] as? String, status == "success" {
                        // Handle success
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
