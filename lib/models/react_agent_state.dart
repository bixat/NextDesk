/// ReAct Agent State Management
class ReActAgentState {
  String currentThought = '';
  String lastObservation = '';
  String nextAction = '';
  int iterationCount = 0;
  bool isReasoning = false;

  void reset() {
    currentThought = '';
    lastObservation = '';
    nextAction = '';
    iterationCount = 0;
    isReasoning = false;
  }

  Map<String, dynamic> toJson() {
    return {
      'current_thought': currentThought,
      'last_observation': lastObservation,
      'next_action': nextAction,
      'iteration_count': iterationCount,
      'is_reasoning': isReasoning,
    };
  }
}
