# fail-if-any-step-failed stepaction

This StepAction searches for exit codes (/tekton/steps/<step-name>/exitCode) in each step within the Task and fails if it detects that any `exitCode != "0"`
