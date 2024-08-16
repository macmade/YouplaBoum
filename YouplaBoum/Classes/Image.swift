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
import UniformTypeIdentifiers

@objc
public class Image: NSObject
{
    private static let queue = OperationQueue()

    @objc public private( set ) dynamic var url:           URL
    @objc public private( set ) dynamic var name:          String
    @objc public private( set ) dynamic var type:          UTType
    @objc public private( set ) dynamic var size:          NSSize
    @objc public private( set ) dynamic var bytes:         Int
    @objc public private( set ) dynamic var source:        NSImage?
    @objc public private( set ) dynamic var thumbnail:     NSImage?
    @objc public                dynamic var isSelected:    Bool
    @objc public                dynamic var isHighlighted: Bool
    @objc public                dynamic var trashed:       Bool

    private var thumbnailOperation: Operation?

    public init?( url: URL )
    {
        guard let uti = UTType( filenameExtension: url.pathExtension ), uti.conforms( to: .image )
        else
        {
            return nil
        }

        guard let image = NSImage( byReferencingFile: url.path( percentEncoded: false ) )
        else
        {
            return nil
        }

        guard let bytes = try? url.resourceValues( forKeys: [ .fileSizeKey ] ).fileSize, bytes > 0
        else
        {
            return nil
        }

        self.url           = url
        self.name          = url.lastPathComponent
        self.type          = uti
        self.size          = image.size
        self.bytes         = bytes
        self.isSelected    = false
        self.isHighlighted = false
        self.trashed       = false
    }

    public func loadSourceImage()
    {
        self.source = NSImage( byReferencingFile: self.url.path( percentEncoded: false ) )
    }

    public func unloadSourceImage()
    {
        self.source = nil
    }

    public func generateThumbnail()
    {
        if self.thumbnail != nil || self.thumbnailOperation != nil
        {
            return
        }

        let operation = BlockOperation
        {
            guard let source = NSImage( byReferencingFile: self.url.path( percentEncoded: false ) )
            else
            {
                return
            }

            let height    = 100.0
            let width     = ( height * source.size.width ) / source.size.height
            let thumbnail = NSImage( size: NSSize( width: width, height: height ) )

            thumbnail.lockFocus()
            source.draw( in: NSRect( x: 0, y: 0, width: thumbnail.size.width, height: thumbnail.size.height ) )
            thumbnail.unlockFocus()

            DispatchQueue.main.async
            {
                self.thumbnail          = thumbnail
                self.thumbnailOperation = nil
            }
        }

        self.thumbnailOperation = operation

        Image.queue.addOperation( operation )
    }

    public func cancelThumbnailGeneration()
    {
        self.thumbnailOperation?.cancel()
    }
}
