# Team Radio Privacy Policy

_Last updated: September 11, 2026_

Team Radio collects the minimum needed to run its features, none of it linked
to your identity, and nothing is ever sold or shared.

- **No accounts.** The app has no sign-up, login, or passwords. The Paddock
  chat identifies you only by a paddock name you choose.
- **No analytics or tracking.** The app contains no analytics SDKs, no
  advertising SDKs, and no trackers of any kind.
- **Paddock chat.** Messages you post and the paddock name you register are
  stored in Apple's CloudKit public database so other users of the app can
  see them — that is the point of a public chat room. They are tied to an
  anonymous CloudKit identifier, not to your name, email, or phone number.
  Long-press any message to report or block; reported content is reviewed
  and removed.
- **Session alerts (push).** To start the Lock Screen session countdown
  automatically, the app registers an anonymous Apple push token with our
  notification server (hosted on Cloudflare). The token identifies your
  device for push delivery only, is linked to nothing else, and is deleted
  when it stops working. To opt out, disable notifications for Team Radio in
  iOS Settings.
- **Private messages.** One-to-one messages are stored in the same CloudKit
  public database but are end-to-end encrypted on your device: each
  participant holds a key that never leaves their devices, and only the two
  of you can read the text. The sender and recipient paddock names and the
  time of each message are not encrypted. Reporting a private message sends
  its decrypted text to the developer for review; blocking hides all messages
  from that person. New-message notifications are delivered by Apple's
  CloudKit; the notification carries only the sender's name.
- **GIFs in chat.** GIF search inside the Paddock is provided by GIPHY: the
  words you search for are sent to GIPHY to return results, and shared GIFs
  are loaded from GIPHY's servers. GIPHY's own privacy policy applies to
  those requests; Team Radio does not store your searches.
- **Local preferences** (notification choices, spoiler mode, read state)
  stay on your device.
- **Network requests** fetch public sports data: the Jolpica F1 API (race
  schedules, results, standings), the MultiViewer API (circuit geometry),
  OpenStreetMap-derived circuit data bundled with the app, Open-Meteo
  (weather), and public RSS news feeds (Formula1.com, BBC Sport,
  Motorsport.com). These requests contain no personal information beyond
  what any internet request technically includes (such as your IP address,
  which Team Radio does not log or store). The operators of those services
  may have their own privacy policies.

If you have any questions about this policy, please open an issue on the
project's GitHub repository.
