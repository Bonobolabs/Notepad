//
//  Theme.swift
//  Notepad
//
//  Created by Rudd Fawcett on 10/14/16.
//  Copyright © 2016 Rudd Fawcett. All rights reserved.
//

#if os(iOS)
    import UIKit
#elseif os(macOS)
    import AppKit
#endif

public struct Theme {

    public enum BuiltIn: String {
        case Base16TomorrowDark = "base16-tomorrow-dark"
        case Base16TomorrowLight = "base16-tomorrow-light"
        case BluesClues = "blues-clues"
        case OneDarkCustom = "one-dark-custom"
        case OneLightCustom = "one-light-custom"
        case OneDark = "one-dark"
        case OneLight = "one-light"
        case SolarizedDark = "solarized-dark"
        case SolarizedLight = "solarized-light"
        case SystemMinimal = "system-minimal"

        public func theme() -> Theme {
            return Theme(self.rawValue)
        }
    }

    /// The body style for the Notepad editor.
    public var body: Style = Style()
    /// The background color of the Notepad.
    public var backgroundColor: UniversalColor = UniversalColor.clear
    /// The tint color (AKA cursor color) of the Notepad.
    public var tintColor: UniversalColor = UniversalColor.blue

    /// All of the other styles for the Notepad editor.
    public var styles: [Style] = []
    
    public func style(withName name: String) -> Style? {
        styles.first(where: { $0.name == name })
    }

    /// Build a theme from a JSON theme file.
    ///
    /// - parameter name: The name of the JSON theme file.
    ///
    /// - returns: The Theme.
    public init(_ name: String) {
        let bundle = Bundle(for: Notepad.self)
        
        let path: String
        
        if let path1 = bundle.path(forResource: "Notepad.framework/themes/\(name)", ofType: "json") {
            
            path = path1
        }
        else if let path2 = bundle.path(forResource: "Notepad.framework/\(name)", ofType: "json") {
            
            path = path2
        }
        else if let path3 = bundle.path(forResource: "themes/\(name)", ofType: "json") {

            path = path3
        }
        else if let path4 = bundle.path(forResource: name, ofType: "json") {
            
            path = path4
        }
        else {
            
            print("[Notepad] Unable to load your theme file.")
            assertionFailure()
            return
        }
        
        if let data = convertFile(path) {
            configure(data)
        }
    }
    
    public init(themePath: String) {
        if let data = convertFile(themePath) {
            configure(data)
        }
    }
    
    public init() {
    }

    /// Configures all of the styles for the Theme.
    ///
    /// - parameter data: The dictionary data form the parsed JSON file.
    mutating func configure(_ data: [String: AnyObject]) {
        if let editorStyles = data["editor"] as? [String: AnyObject] {
            configureEditor(editorStyles)
        }

        if var allStyles = data["styles"] as? [String: AnyObject] {
            if let bodyStyles = allStyles["body"] as? [String: AnyObject] {
                var parsedBodyStyles = parse(bodyStyles)
                if #available(iOS 13.0, *) {
                    if parsedBodyStyles[NSAttributedString.Key.foregroundColor] == nil {
                        parsedBodyStyles[NSAttributedString.Key.foregroundColor] = UniversalColor.label
                    }
                }
                body = Style(element: .body, attributes: parsedBodyStyles)
            }
            else { // Create a default body font so other styles can inherit from it.
                var textColor = UniversalColor.black
                if #available(iOS 13.0, *) {
                    textColor = UniversalColor.label
                }
                let attributes = [NSAttributedString.Key.foregroundColor: textColor]
                body = Style(element: .body, attributes: attributes)
            }

            allStyles.removeValue(forKey: "body")
            for (element, attributes) in allStyles {
                styles.append(createStyle(element: element, attributes: attributes as! [String : AnyObject], allStyles: allStyles))
            }
        }
    }
    
    mutating func createStyle(element: String, attributes: [String: AnyObject], allStyles: [String : AnyObject], parent: Style? = nil) -> Style {
        
        var style: Style
        let parsedStyles = parse(attributes, parentStyle: parent)
        if let regexString = attributes["regex"] as? String {
            let regex = regexString.toRegex()
            style = Style(regex: regex, attributes: parsedStyles, name: element)
        } else {
            style = Style(element: Element.unknown.from(string: element), attributes: parsedStyles, name: element)
        }
        
        if let groups = attributes["groups"] as? [String] {
            var subStyles = [Style]()
            for group in groups {
                if let subAttribs = allStyles[group] {
                    subStyles.append(createStyle(element: group, attributes: subAttribs as! [String : AnyObject], allStyles: allStyles, parent: style))
                }
            }
            style.styles = subStyles
        }
        
        return style
    }

    /// Sets the background color, tint color, etc. of the Notepad editor.
    ///
    /// - parameter attributes: The attributes to parse for the editor.
    mutating func configureEditor(_ attributes: [String: AnyObject]) {
        if let bgColor = attributes["backgroundColor"] {
            let value = bgColor as! String
            backgroundColor = UniversalColor(hexString: value)
        }

        if let tint = attributes["tintColor"] {
            let value = tint as! String
            tintColor = UniversalColor(hexString: value)
        }
    }

    /// Parses attributes from shorthand JSON to real attributed string key constants.
    ///
    /// - parameter attributes: The attributes to parse.
    ///
    /// - returns: The converted attribute/key constant pairings.
    func parse(_ attributes: [String: AnyObject]?, parentStyle: Style? = nil) -> [NSAttributedString.Key: Any] {
        var stringAttributes: [NSAttributedString.Key: Any] = [:]
        
        guard let attributes = attributes else { return stringAttributes }

        if let color = attributes["color"] as? String {
            stringAttributes[NSAttributedString.Key.foregroundColor] = UniversalColor(hexString: color)
        }
        
        let parentFont = (parentStyle?.attributes[NSAttributedString.Key.font] ?? body.attributes[NSAttributedString.Key.font]) as? UniversalFont
        // if size is set use custom size, otherwise use body font size, otherwise fallback to 15 points
        let fontSize: CGFloat = attributes["size"] as? CGFloat ?? (parentFont?.pointSize ?? 15)
        let fontTraits = attributes["traits"] as? String ?? ""
        var font: UniversalFont?
        
        if let fontName = attributes["font"] as? String {
            if fontName == "System" {
                // allow explicit system font use in styles other than body
                font = UniversalFont.systemFont(ofSize: fontSize).with(traits: fontTraits, size: fontSize)
            } else {
                // use custom font if set
                font = UniversalFont(name: fontName, size: fontSize)?.with(traits: fontTraits, size: fontSize)
            }
        } else if let parentFont = parentFont {
            // use parent font if set
            font = parentFont.with(traits: fontTraits, size: fontSize)
        } else {
            // No fallback to "System" - use whatever is already set on the attributed string.
        }
        if font != nil {
            stringAttributes[NSAttributedString.Key.font] = font
        }
        
        return stringAttributes
    }

    /// Converts a file from JSON to a [String: AnyObject] dictionary.
    ///
    /// - parameter path: The path to the JSON file.
    ///
    /// - returns: The new dictionary.
    func convertFile(_ path: String) -> [String: AnyObject]? {
        do {
            let json = try String(contentsOf: URL(fileURLWithPath: path), encoding: .utf8)
            if let data = json.data(using: .utf8) {
                do {
                    return try JSONSerialization.jsonObject(with: data, options: []) as? [String: AnyObject]
                } catch let error as NSError {
                    print(error)
                }
            }
        } catch let error as NSError {
            print(error)
        }

        return nil
    }
}
