/*******************************************************************************
 * The MIT License (MIT)
 *
 * Copyright (c) 2023, Jean-David Gadina - www.xs-labs.com
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the Software), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED AS IS, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 ******************************************************************************/

import Cocoa
import CoreServices

class Application: NSObject
{
    public class func createMenu( for url: URL ) -> NSMenu?
    {
        let apps = Application.applicationsForFileExtension( url.pathExtension ).sorted
        {
            ( $0.name as NSString ).localizedCaseInsensitiveCompare( $1.name ) == .orderedAscending
        }

        let menu  = NSMenu()
        let items = apps.map
        {
            let item               = menu.addItem( withTitle: $0.name, action: nil, keyEquivalent: "" )
            item.image             = $0.icon
            item.image?.size       = NSMakeSize( 20, 20 )
            item.representedObject = ( $0, url )
            item.target            = $0
            item.action            = #selector( openItems( _: ) )

            return item
        }

        if items.isEmpty
        {
            return nil
        }

        return menu
    }

    public class func applicationsForFileExtension( _ ext: String ) -> [ Application ]
    {
        let dir  = NSTemporaryDirectory() as NSString
        let uuid = UUID().uuidString

        guard let temp = ( dir.appendingPathComponent( uuid ) as NSString ).appendingPathExtension( ext )
        else
        {
            return []
        }

        FileManager.default.createFile( atPath: temp, contents: nil, attributes: nil )

        guard let apps = LSCopyApplicationURLsForURL( URL( fileURLWithPath: temp ) as CFURL, .all )?.takeRetainedValue() as? [ URL ]
        else
        {
            return []
        }

        return apps.map { Application( url: $0 ) }
    }

    @objc public dynamic var url:  URL
    @objc public dynamic var name: String
    @objc public dynamic var icon: NSImage

    private init( url: URL )
    {
        self.url  = url
        self.name = FileManager.default.displayName( atPath: url.path )
        self.icon = NSWorkspace.shared.icon( forFile: url.path )
    }

    override func isEqual( _ object: Any? ) -> Bool
    {
        guard let app = object as? Application
        else
        {
            return false
        }

        return self.url == app.url
    }

    @IBAction
    private func openItems( _ sender: Any? )
    {
        guard let menuItem = sender                     as? NSMenuItem,
              let info     = menuItem.representedObject as? ( Application, URL )
        else
        {
            return
        }

        NSWorkspace.shared.open( [ info.1 ], withApplicationAt: info.0.url, configuration: NSWorkspace.OpenConfiguration() )
    }
}
