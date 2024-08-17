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

@objc
public class MainWindowController: NSWindowController, NSCollectionViewDelegate, NSCollectionViewDataSource, NSMenuDelegate
{
    private let itemID = NSUserInterfaceItemIdentifier( "ImageItem" )

    @objc private dynamic var url:           URL
    @objc private dynamic var progress:      Progress?
    @objc private dynamic var info:          String?
    @objc private dynamic var images       = [ Image ]()
    @objc private dynamic var showInfo     = Preferences.shared.showInfo
    @objc private dynamic var currentImage:  Image?
    @objc private dynamic var currentIndex = -1
    {
        didSet
        {
            if self.currentIndex >= 0
            {
                let current  = self.images[ self.currentIndex ]
                let previous = self.currentIndex - 1 >= 0                ? self.images[ self.currentIndex - 1 ] : nil
                let next     = self.currentIndex + 1 < self.images.count ? self.images[ self.currentIndex + 1 ] : nil

                self.images.forEach
                {
                    if $0 !== current, $0 !== previous, $0 !== next
                    {
                        $0.unloadSourceImage()
                    }
                    else
                    {
                        $0.loadSourceImage()
                    }

                    $0.isHighlighted = $0 === current
                }

                self.currentImage            = current
                self.infoViewController.tags = current.tags

                self.updateInfo()

                if self.collectionView?.numberOfItems( inSection: 0 ) ?? 0 > self.currentIndex
                {
                    let indexes = Set< IndexPath >( [ IndexPath( item: self.currentIndex, section: 0 ) ] )

                    self.collectionView?.scrollToItems( at: indexes, scrollPosition: .centeredHorizontally )
                }
            }
            else
            {
                self.currentImage            = nil
                self.infoViewController.tags = []
                self.info                    = nil
            }
        }
    }

    private var averageColorObserver: NSKeyValueObservation?
    private var infoViewController  = InfoViewController()

    @IBOutlet private var collectionView:        NSCollectionView?
    @IBOutlet private var imageBackgroundView:   BackgroundView?
    @IBOutlet private var infoViewContainer:     NSView?
    @IBOutlet private var imageMenu:             NSMenu?

    public init( url: URL )
    {
        self.url = url

        super.init( window: nil )
    }

    public required init?( coder: NSCoder )
    {
        nil
    }

    public override var windowNibName: NSNib.Name?
    {
        "MainWindowController"
    }

    public override func windowDidLoad()
    {
        super.windowDidLoad()
        self.collectionView?.register( NSNib( nibNamed: "ImageItem", bundle: nil ), forItemWithIdentifier: self.itemID )
        self.load()

        self.window?.title = "YouplaBoum! - \( self.url.deletingLastPathComponent().lastPathComponent )/\( self.url.lastPathComponent )"

        self.averageColorObserver = self.observe( \.currentImage?.averageColor )
        {
            [ weak self ] _, _ in

            self?.imageBackgroundView?.color = self?.currentImage?.averageColor ?? .black
        }

        self.infoViewContainer?.addFillingSubview( self.infoViewController.view )

        NSEvent.addLocalMonitorForEvents( matching: .keyDown )
        {
            guard $0.window === self.window
            else
            {
                return $0
            }

            if $0.keyCode == 123 // Left arrow
            {
                self.previous()

                return nil
            }
            else if $0.keyCode == 124 // Right arrow
            {
                self.next()

                return nil
            }
            else if $0.keyCode == 49 // Space
            {
                self.currentImage?.isSelected.toggle()
                self.updateInfo()

                return nil
            }

            return $0
        }
    }

    @IBAction
    private func showInfo( _ sender: Any? )
    {
        self.showInfo.toggle()

        Preferences.shared.showInfo = self.showInfo
    }

    @IBAction
    private func reset( _ sender: Any? )
    {
        guard let window = self.window
        else
        {
            NSSound.beep()

            return
        }

        let alert             = NSAlert()
        alert.messageText     = "Reset Image Selection"
        alert.informativeText = "Are you sure you want to reset the selection state for all images?"

        alert.addButton( withTitle: "Reset" )
        alert.addButton( withTitle: "Cancel" )

        alert.beginSheetModal( for: window )
        {
            if $0 == .alertFirstButtonReturn
            {
                self.images.forEach
                {
                    $0.isSelected = false
                }

                self.updateInfo()
            }
        }
    }

    @IBAction
    private func process( _ sender: Any? )
    {
        guard let window = self.window
        else
        {
            NSSound.beep()

            return
        }

        let alert             = NSAlert()
        alert.messageText     = "Process Selected Images"
        alert.informativeText = "What would you like to do with selected images?"

        alert.addButton( withTitle: "Keep Only Selected Images" )
        alert.addButton( withTitle: "Trash Selected Images" )
        alert.addButton( withTitle: "Cancel" )

        alert.beginSheetModal( for: window )
        {
            if $0 == .alertThirdButtonReturn
            {
                return
            }

            let keepSelected = $0 == .alertFirstButtonReturn
            self.progress    = Progress( message: "Processing Images...", isIndeterminate: true, maxValue: 0 )

            DispatchQueue.global( qos: .userInitiated ).async
            {
                self.images.forEach
                {
                    if ( $0.isSelected && keepSelected == false ) || ( $0.isSelected == false && keepSelected )
                    {
                        do
                        {
                            try FileManager.default.trashItem( at: $0.url, resultingItemURL: nil )

                            $0.trashed = true
                        }
                        catch
                        {
                            DispatchQueue.main.async
                            {
                                self.showError( error.localizedDescription )
                            }
                        }
                    }
                }

                let result = self.images.filter
                {
                    $0.trashed == false
                }

                DispatchQueue.main.async
                {
                    if result.isEmpty
                    {
                        let alert             = NSAlert()
                        alert.messageText     = "No Image Left"
                        alert.informativeText = "All images were moved to the trash."

                        alert.beginSheetModal( for: window )
                        {
                            _ in self.close()
                        }
                    }
                    else
                    {
                        self.images = result

                        self.collectionView?.reloadData()

                        self.currentIndex = 0
                        self.progress     = nil

                        self.updateInfo()
                    }
                }
            }
        }
    }

    private func updateInfo()
    {
        let selected = self.images.reduce( 0 )
        {
            $1.isSelected ? $0 + 1 : $0
        }

        self.info = "\( self.currentIndex + 1 ) of \( self.images.count ) - \( selected ) Selected"
    }

    private func previous()
    {
        self.currentIndex = self.currentIndex > 0 ? self.currentIndex - 1 : self.currentIndex
    }

    private func next()
    {
        self.currentIndex = self.currentIndex < self.images.count - 1 ? self.currentIndex + 1 : self.currentIndex
    }

    private func showError( _ message: String )
    {
        let alert             = NSAlert()
        alert.messageText     = "Error"
        alert.informativeText = message

        if let window = self.window
        {
            alert.beginSheetModal( for: window )
            {
                _ in self.close()
            }
        }
        else
        {
            alert.runModal()
            self.close()
        }
    }

    private func load()
    {
        DispatchQueue.main.async
        {
            if self.progress != nil
            {
                return
            }

            let progress  = Progress( message: "Loading images - Please wait...", isIndeterminate: true, maxValue: 0 )
            self.progress = progress

            DispatchQueue.global( qos: .userInitiated ).async
            {
                defer
                {
                    DispatchQueue.main.async
                    {
                        self.progress = nil
                    }
                }

                do
                {
                    let images = try self.loadImages().sorted
                    {
                        let s1 = $0.url.path( percentEncoded: false )
                        let s2 = $1.url.path( percentEncoded: false )

                        return s1.localizedCaseInsensitiveCompare( s2 ) == .orderedAscending
                    }

                    DispatchQueue.main.async
                    {
                        if images.isEmpty
                        {
                            self.showError( "No images were found in the selected directory." )
                        }
                        else
                        {
                            self.images       = images
                            self.currentIndex = 0

                            self.collectionView?.reloadData()
                        }
                    }
                }
                catch
                {
                    DispatchQueue.main.async
                    {
                        self.showError( error.localizedDescription )
                    }
                }
            }
        }
    }

    private func loadImages() throws -> [ Image ]
    {
        guard let enumerator = FileManager.default.enumerator( atPath: self.url.path( percentEncoded: false ) )
        else
        {
            throw RuntimeError( message: "Cannot read directory: \( self.url.lastPathComponent )" )
        }

        return enumerator.compactMap
        {
            guard let name = $0 as? String
            else
            {
                return nil
            }

            return Image( url: self.url.appending( path: name ) )
        }
    }

    public func collectionView( _ collectionView: NSCollectionView, numberOfItemsInSection section: Int ) -> Int
    {
        self.images.count
    }

    public func collectionView( _ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath ) -> NSCollectionViewItem
    {
        guard let item = collectionView.makeItem( withIdentifier: self.itemID, for: indexPath ) as? ImageItem
        else
        {
            return NSCollectionViewItem()
        }

        item.image = self.images[ indexPath.item ]

        return item
    }

    public func collectionView( _ collectionView: NSCollectionView, willDisplay item: NSCollectionViewItem, forRepresentedObjectAt indexPath: IndexPath )
    {
        if let item = item as? ImageItem
        {
            item.image?.generateThumbnail()
        }
    }

    public func collectionView( _ collectionView: NSCollectionView, didEndDisplaying item: NSCollectionViewItem, forRepresentedObjectAt indexPath: IndexPath )
    {
        if let item = item as? ImageItem
        {
            item.image?.cancelThumbnailGeneration()
        }
    }

    public func collectionView( _ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set< IndexPath > )
    {
        guard let indexPath = indexPaths.first
        else
        {
            return
        }

        self.currentIndex = indexPath.item
    }

    @IBAction
    private func showMenu( _ sender: Any? )
    {
        guard let view  = sender as? NSView,
              let menu  = self.imageMenu,
              let event = NSApp.currentEvent
        else
        {
            NSSound.beep()

            return
        }

        NSMenu.popUpContextMenu( menu, with: event, for: view )
    }

    @IBAction
    private func showInFinder( _ sender: Any? )
    {
        guard let url = self.currentImage?.url
        else
        {
            NSSound.beep()

            return
        }

        NSWorkspace.shared.selectFile( url.path( percentEncoded: false ), inFileViewerRootedAtPath: "" )
    }

    @IBAction
    private func openWithExternalEditor( _ sender: Any? )
    {
        guard let url = self.currentImage?.url
        else
        {
            NSSound.beep()

            return
        }

        NSWorkspace.shared.open( url )
    }

    @IBAction
    private func share( _ sender: Any? )
    {
        guard let url  = self.currentImage?.url,
              let view = self.window?.contentView
        else
        {
            NSSound.beep()

            return
        }

        NSSharingServicePicker( items: [ url ] ).show( relativeTo: .zero, of: view, preferredEdge: .maxX )
    }

    public func menuWillOpen( _ menu: NSMenu )
    {
        menu.items.forEach
        {
            if $0.identifier?.rawValue == "OpenWith"
            {
                $0.isHidden = true
            }
        }

        guard let url = self.currentImage?.url
        else
        {
            return
        }

        menu.items.forEach
        {
            if $0.identifier?.rawValue == "OpenWith",
               let menu = Application.createMenu( for: url )
            {
                $0.isHidden = false
                $0.submenu  = menu
            }
        }
    }
}
