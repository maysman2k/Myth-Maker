import Foundation

/// Legal copy shown in Settings. These are plain-English starting points
/// written to reflect how the app actually behaves today; they should be
/// reviewed by a legal professional before App Store release, and the
/// privacy text expanded once advertising or analytics are added.
enum LegalContent {

    static let company = "Bricks in a Bag"
    static let contactEmail = "support@bricksinabag.com"
    static let lastUpdated = "June 2026"

    static let privacyPolicy = """
    Wait Less — Privacy Policy
    Last updated: \(lastUpdated)

    Wait Less is built to need as little of your information as possible. \
    There is no account to create and we do not ask for your name, email or \
    phone number to use the app.

    Information the app uses

    • Location. If you allow it, the app uses your device location to centre \
    the map near you and to find bus stops nearby. Your location is used on \
    your device and sent to our servers only as map coordinates to fetch the \
    bus information for that area. We do not store your location or link it to \
    you. You can turn location access off at any time in iOS Settings; the app \
    still works, you just search for places manually.

    • Information stored on your device. Your favourite stops and routes, your \
    downloaded offline timetables, and your settings are saved on your device \
    only. They are not uploaded to us or shared.

    • Basic technical requests. To show live buses and timetables, the app \
    asks our servers for the data covering the area or route you are looking \
    at. These requests are not used to build a profile of you.

    Information we do not collect

    We do not collect contacts, photos, health data, or advertising identifiers, \
    and we do not track you across other apps or websites.

    Where the bus data comes from

    Bus locations and timetables are derived from the UK Department for \
    Transport's Bus Open Data Service, published under the Open Government \
    Licence v3.0. See the Data & Attribution page for details.

    Children

    Wait Less is suitable for general audiences and is not directed at children \
    under 13. We do not knowingly collect personal information from children.

    Your rights

    Because we do not hold personal information that identifies you, there is \
    normally nothing for us to retrieve or delete on your behalf. Information \
    stored on your device can be removed by deleting saved timetables in \
    Settings, or by deleting the app. If you have any privacy question, contact \
    us at \(contactEmail).

    Changes

    If this policy changes, we will update it here and revise the date above.

    Contact

    \(company) — \(contactEmail)
    """

    static let termsOfUse = """
    Wait Less — Terms of Use
    Last updated: \(lastUpdated)

    Please read these terms before using Wait Less. By using the app you agree \
    to them.

    What the app is

    Wait Less shows live bus positions and timetable information for the United \
    Kingdom, based on open data published by bus operators and the Department \
    for Transport. It is an independent app and is not affiliated with, or \
    endorsed by, the Department for Transport or any bus operator.

    Accuracy and reliance

    The information is provided "as is" and "as available". Live positions and \
    times depend on data supplied by third parties and can be delayed, \
    incomplete, or wrong. Do not rely on Wait Less alone where catching a \
    particular service matters — for example for medical appointments, flights, \
    or the last bus home. Always allow extra time and check official sources.

    No liability

    To the fullest extent permitted by law, \(company) is not liable for any \
    loss or inconvenience arising from missed or delayed services, inaccurate \
    information, or any interruption to the app or its data.

    Acceptable use

    Use the app for personal, lawful purposes. Do not attempt to disrupt, \
    overload, reverse engineer, or misuse the app or the services it relies on.

    Changes and availability

    We may update, change, or withdraw features at any time, and the service may \
    occasionally be unavailable.

    Governing law

    These terms are governed by the laws of England and Wales.

    Contact

    \(company) — \(contactEmail)
    """

    static let dataAttribution = """
    Data & Attribution
    Last updated: \(lastUpdated)

    Wait Less uses public sector information from the United Kingdom Department \
    for Transport's Bus Open Data Service (BODS).

    Contains public sector information licensed under the Open Government \
    Licence v3.0.

    Bus timetables and live vehicle locations are published by bus operators \
    through BODS as required by law, and made available under the Open \
    Government Licence v3.0. Wait Less processes this open data to present it \
    in a more convenient form. It does not change the underlying meaning of the \
    data, but it cannot guarantee its accuracy or completeness.

    Open Government Licence:
    https://www.nationalarchives.gov.uk/doc/open-government-licence/version/3/

    Bus Open Data Service:
    https://www.bus-data.dft.gov.uk

    Contact

    \(company) — \(contactEmail)
    """
}
