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
    @objc public private( set ) dynamic var averageColor:  NSColor
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
        self.averageColor  = .black
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

            let average = self.getAverageColor( image: thumbnail )

            DispatchQueue.main.async
            {
                self.thumbnail          = thumbnail
                self.thumbnailOperation = nil
                self.averageColor       = average ?? .black
            }
        }

        self.thumbnailOperation = operation

        Image.queue.addOperation( operation )
    }

    public func cancelThumbnailGeneration()
    {
        self.thumbnailOperation?.cancel()
    }

    // Code borrowed from an article by Paul Hudson
    // See: https: // www.hackingwithswift.com/example-code/media/how-to-read-the-average-color-of-a-uiimage-using-ciareaaverage
    private func getAverageColor( image: NSImage ) -> NSColor?
    {
        guard let cgImage = image.cgImage( forProposedRect: nil, context: nil, hints: nil )
        else
        {
            return nil
        }

        let inputImage   = CIImage( cgImage: cgImage )
        let extentVector = CIVector( x: inputImage.extent.origin.x, y: inputImage.extent.origin.y, z: inputImage.extent.size.width, w: inputImage.extent.size.height )

        guard let filter      = CIFilter( name: "CIAreaAverage", parameters: [ kCIInputImageKey: inputImage, kCIInputExtentKey: extentVector ] ),
              let outputImage = filter.outputImage
        else
        {
            return nil
        }

        var bitmap  = [ UInt8 ]( repeating: 0, count: 4 )
        let context = CIContext( options: [ : ] )

        context.render( outputImage, toBitmap: &bitmap, rowBytes: 4, bounds: CGRect( x: 0, y: 0, width: 1, height: 1 ), format: .RGBA8, colorSpace: nil )

        return NSColor( red: CGFloat( bitmap[ 0 ] ) / 255, green: CGFloat( bitmap[ 1 ] ) / 255, blue: CGFloat( bitmap[ 2 ] ) / 255, alpha: CGFloat( bitmap[ 3 ] ) / 255 )
    }
}
