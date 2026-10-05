# Deliver captures as hidden prompt context plus a screenshot Claude opens itself

In the desktop app a mod can't fill the prompt box or attach an image: `$.prompt.fill` refuses with `no_composer`, and no plugin API puts an image block in front of the model. So the Mod adds each Capture's Screen text to the sent message's hidden `context` and tells Claude to open the Screenshot with its Read tool, which a permission rule allows for `~/.claude/screen-context/` without asking. The prompt box only ever shows a one-line marker per Capture (new sessions) or a bar above it (existing sessions).
