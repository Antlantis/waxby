extends RefCounted
## The game's few ways out to the web, all opened in the phone's browser (or
## the App Store) with OS.shell_open, never inside the game: the privacy
## policy and the support page (the website, antlantis.github.io/waxby,
## published by the author) and "Rate Waxby" (the App Store's review sheet).
## The title shows Privacy; the Settings page (settings_page.gd: the title's,
## the map's and the pause menu's) shows all of them. Waxby itself never
## goes online: these only hand a link to the system.
##
## WAXBY_APP_ID is Waxby's numeric Apple ID in App Store Connect (the build 4
## upload's adamId, waxby.xcarchive/Info.plist). While it is "", the Rate
## link hides. Headless (the tests, the tools) a link is only noted in
## `opened`, never opened.

const SITE := "https://antlantis.github.io/waxby/"
const PRIVACY_URL := SITE + "privacy.html"
const SUPPORT_URL := SITE + "support.html"
const WAXBY_APP_ID := "6817044506"
const REVIEW_URL := "https://apps.apple.com/app/id%s?action=write-review"

static var app_id := WAXBY_APP_ID   # tests may blank it to see the Rate link hide
static var opened: Array = []       # every link asked for, in order (the tests read it)


static func review_url() -> String:
	## The App Store's "Write a Review" for Waxby, or "" without an app id.
	return REVIEW_URL % app_id if app_id != "" else ""


static func can_rate() -> bool:
	return review_url() != ""


static func open(url: String) -> bool:
	## Hands url to the system (Safari, or the App Store for its own links).
	## False for an empty one, or when the system won't open it.
	if url == "":
		return false
	opened.append(url)
	if DisplayServer.get_name() == "headless":
		return true
	return OS.shell_open(url) == OK


static func privacy() -> bool:
	return open(PRIVACY_URL)


static func support() -> bool:
	return open(SUPPORT_URL)


static func rate() -> bool:
	return open(review_url())
