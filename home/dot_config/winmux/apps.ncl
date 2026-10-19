# App groups and window tests shared by laptop.ncl and ultrawide.ncl.
{
  is-app = fun ids w => std.array.elem w.app.bundleId ids,
  # Self Service's admin sign-in is an ephemeral ASWebAuthenticationSession
  # window in the default browser. At placement its title is "Untitled - …
  # (Incognito)" and `document` is about:blank, so the Chromium incognito
  # suffix is the only signal; Safari and Arc private windows carry no such
  # suffix.
  is-incognito = fun w => std.string.contains "(Incognito)" w.title,
  browsers = ["com.talon-sec.Work", "com.google.Chrome", "company.thebrowser.Browser"],
  editors = ["com.todesktop.230313mzl4w4u92", "com.stablyai.orca"],
  comms = ["io.agentsview.desktop", "com.tinyspeck.slackmacgap", "us.zoom.xos", "com.jamfsoftware.selfservice.mac"],
  utilities = ["com.1password.1password"],
}
