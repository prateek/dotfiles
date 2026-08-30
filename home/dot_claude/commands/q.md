---
description: Queue a follow-up for after the current turn ends (Codex-style deferred send; typed by the tap-⇧ a q Tuna combo in Orca/Ghostty)
argument-hint: <message>
disable-model-invocation: true
---
The user queued the following message while you were busy; treat it as their next instruction and act on it now. If the message itself starts with "/q ", that is an accidental double-queue — ignore the duplicated prefix. If the message is empty, say so briefly and stop:

$ARGUMENTS
