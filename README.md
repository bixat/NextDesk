# ReAct AI Desktop Automation Agent

An intelligent desktop automation application powered by Google's Gemini AI that uses the **ReAct (Reasoning + Acting)** framework to understand and execute complex computer tasks through natural language commands.

## 🌟 Overview

This Flutter desktop application combines AI reasoning with computer vision and input control to automate desktop tasks. Simply describe what you want to do in natural language (e.g., "open Chrome and search for Flutter documentation"), and the AI agent will break it down into executable steps, reason about each action, and perform the automation.

## 🏗️ Project Structure

```
desktop_agent/
├── lib/
│   ├── main.dart              # Main application entry point & all core logic
│   ├── main.g.dart            # Generated Isar database code
│   └── services/              # (Currently empty - future modular services)
├── macos/                     # macOS platform-specific code
├── windows/                   # Windows platform-specific code
├── linux/                     # Linux platform-specific code
├── pubspec.yaml               # Dependencies and project configuration
└── README.md                  # This file
```

### Key Components in `main.dart`

The application is structured as a single-file architecture with the following main components:

1. **Data Models**
   - `Task`: Isar database model for storing automation tasks
   - `DetectionResult`: Model for UI element detection results
   - `ReActAgentState`: State management for the ReAct reasoning cycle

2. **Core Services**
   - `VisionService`: AI-powered UI element detection using Gemini Vision
   - `AutomationFunctions`: Wrapper for all automation capabilities
   - `AppState`: Main state management using Provider

3. **UI Components**
   - `MainScreen`: Primary interface with input, logs, and task history
   - `TaskHistoryPanel`: Displays past automation tasks
   - Custom widgets for execution logs and agent thoughts

## 🧠 How It Works: The ReAct Framework

The application implements the **ReAct (Reasoning + Acting)** pattern, which combines reasoning and action in an iterative loop:

### ReAct Cycle

```
1. THOUGHT → 2. ACTION → 3. OBSERVATION → (repeat)
```

#### 1. **THOUGHT** (Reasoning Phase)
The AI agent analyzes the current state and decides what to do next:
- Understands the user's goal
- Considers what has been done so far
- Plans the next logical step

#### 2. **ACTION** (Acting Phase)
The agent executes one of the available automation functions:
- `captureScreenshot()`: Takes a screenshot to see the current state
- `detectElementPosition(description)`: Finds UI elements using AI vision
- `moveMouse(x, y)`: Moves cursor to coordinates
- `clickMouse(button, action)`: Performs mouse clicks
- `typeText(text)`: Types text via keyboard
- `pressKeys(keys)`: Presses keyboard shortcuts
- `wait(seconds)`: Waits for a specified duration

#### 3. **OBSERVATION** (Feedback Phase)
The agent receives feedback from the action:
- Success/failure status
- Element coordinates (for detection)
- Screenshot data
- Error messages

This cycle repeats until the task is complete or max iterations (20) is reached.

## 🔧 Technical Architecture

### 1. AI Integration (Gemini 2.5 Flash)

The application uses Google's Gemini AI with **function calling** capabilities:

```dart
GenerativeModel(
  model: 'gemini-2.5-flash',
  apiKey: apiKey,
  tools: [
    captureScreenshotTool,
    detectElementTool,
    moveMouseTool,
    clickMouseTool,
    typeTextTool,
    pressKeysTool,
    waitTool,
  ],
)
```

The AI can:
- Understand natural language instructions
- Reason about multi-step tasks
- Call automation functions with appropriate parameters
- Process visual information from screenshots

### 2. Computer Vision (UI Element Detection)

The `VisionService` uses Gemini's vision capabilities to locate UI elements:

1. Takes a screenshot of the current screen
2. Sends the image + element description to Gemini Vision
3. AI analyzes the image and returns pixel coordinates
4. Returns a `DetectionResult` with x, y coordinates and confidence score

Example:
```dart
final result = await visionService.detectElement(
  screenshot: imageBytes,
  elementDescription: "blue Submit button",
);
// Returns: {x: 450, y: 320, confidence: 0.95}
```

### 3. Input Automation

Uses the `bixat_key_mouse` package (custom Rust-based FFI) for:
- **Mouse Control**: Move cursor, click, double-click, right-click
- **Keyboard Control**: Type text, press keys, keyboard shortcuts
- **Screen Capture**: Take screenshots via `screen_capturer`

### 4. State Management (Provider)

The `AppState` class manages:
- Current task execution state
- Execution logs and thought logs
- Screenshot data
- Task history from database
- ReAct agent state (iteration count, current thought, observations)

### 5. Data Persistence (Isar Database)

Tasks are stored locally using Isar (NoSQL database):
```dart
@collection
class Task {
  Id id = Isar.autoIncrement;
  String prompt = '';
  List<String> thoughts = [];  // AI reasoning steps
  List<String> steps = [];     // Executed actions
  bool completed = false;
  DateTime createdAt = DateTime.now();
}
```

## 📦 Dependencies

### Core Packages
- **google_generative_ai** (^0.4.3): Gemini AI integration
- **bixat_key_mouse**: Custom package for mouse/keyboard control
- **screen_capturer** (^0.2.1): Screen capture functionality

### State & Storage
- **provider** (^6.1.1): State management
- **isar** (^3.1.0+1): Local NoSQL database
- **isar_flutter_libs** (^3.1.0+1): Isar platform bindings

### UI & Utilities
- **flutter_animate** (^4.5.0): UI animations
- **google_fonts** (^6.1.0): Typography
- **path_provider** (^2.1.1): File system paths
- **uuid** (^4.2.1): Unique identifiers
- **image** (^4.5.4): Image processing

## 🚀 Getting Started

### Prerequisites
- Flutter SDK (>=3.0.0)
- Gemini API key from [Google AI Studio](https://makersuite.google.com/app/apikey)
- macOS, Windows, or Linux desktop environment

### Installation

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd desktop_agent
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Set up the bixat_key_mouse package**

   Ensure the `bixat_key_mouse_dart` package is available at:
   ```
   ../bixat_key_mouse_dart
   ```

4. **Add your Gemini API key**

   Open `lib/main.dart` and replace the API key:
   ```dart
   const apiKey = 'YOUR_GEMINI_API_KEY_HERE';
   ```

5. **Generate Isar database code**
   ```bash
   flutter pub run build_runner build
   ```

6. **Run the application**
   ```bash
   flutter run -d macos  # or windows/linux
   ```

## 💡 Usage Examples

### Example 1: Simple Web Search
```
Input: "Open Chrome and search for Flutter documentation"

ReAct Process:
THOUGHT: I need to open Chrome first
ACTION: pressKeys(['cmd', 'space'])
OBSERVATION: Spotlight opened

THOUGHT: Now type Chrome to search for it
ACTION: typeText('Chrome')
OBSERVATION: Text typed successfully

THOUGHT: Press Enter to open Chrome
ACTION: pressKeys(['enter'])
OBSERVATION: Chrome is opening

THOUGHT: Wait for Chrome to load
ACTION: wait(2)
OBSERVATION: Waited 2 seconds

THOUGHT: Now I need to click on the address bar
ACTION: captureScreenshot()
OBSERVATION: Screenshot captured

THOUGHT: Detect the address bar
ACTION: detectElementPosition('address bar at the top')
OBSERVATION: Found at x:500, y:100

THOUGHT: Click on the address bar
ACTION: moveMouse(500, 100)
ACTION: clickMouse('left', 'click')
OBSERVATION: Clicked successfully

THOUGHT: Type the search query
ACTION: typeText('Flutter documentation')
ACTION: pressKeys(['enter'])
OBSERVATION: Task complete
```

### Example 2: File Operations
```
Input: "Create a new text file named 'notes.txt' on the desktop"
```

### Example 3: Application Control
```
Input: "Take a screenshot and save it"
```

## 🎯 Key Features

### ✅ Implemented
- ✅ Natural language task understanding
- ✅ ReAct reasoning framework
- ✅ AI-powered UI element detection
- ✅ Mouse and keyboard automation
- ✅ Screenshot capture and analysis
- ✅ Task history and persistence
- ✅ Real-time execution logs
- ✅ Thought process visualization
- ✅ Multi-step task execution

### 🔮 Future Enhancements
- [ ] Multi-monitor support
- [ ] Task templates and macros
- [ ] Voice command input
- [ ] Task scheduling
- [ ] Error recovery and retry logic
- [ ] Performance optimization
- [ ] Plugin system for custom actions
- [ ] Cloud sync for task history

## 🔒 Security & Privacy

- **API Key**: Store your Gemini API key securely (use environment variables in production)
- **Local Processing**: All automation runs locally on your machine
- **Data Storage**: Task history is stored locally using Isar database
- **Screenshots**: Temporary screenshots are kept in memory and not persisted

## 🐛 Troubleshooting

### Common Issues

1. **"Failed to detect element"**
   - Ensure the element description is clear and specific
   - Try taking a screenshot first to verify the UI state
   - Check that the element is visible on screen

2. **"API key error"**
   - Verify your Gemini API key is valid
   - Check your internet connection
   - Ensure you haven't exceeded API quotas

3. **Mouse/keyboard not working**
   - Grant accessibility permissions to the app
   - Check that `bixat_key_mouse` package is properly installed
   - Verify platform-specific permissions

## 📄 License

[Add your license here]

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📧 Contact

[Add your contact information here]

---

**Built with ❤️ using Flutter and Google Gemini AI**
