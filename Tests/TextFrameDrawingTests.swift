// Copyright 2018 Stephan Tolksdorf

import STULabelSwift

import XCTest

class TextFrameDrawingTests: SnapshotTestCase {
  let displayScale: CGFloat = 2

  override func setUp() {
    super.setUp()
    self.imageBaseDirectory = pathRelativeToCurrentSourceDir("ReferenceImages")
  }

  func testBaseCTMHandling() {
    let font = UIFont(name: "HelveticaNeue", size: 18)!
    let shadow = NSShadow()
    shadow.shadowOffset = CGSize(width: 8, height: 4)
    shadow.shadowBlurRadius = 2
    let frame = STUTextFrame(STUShapedString(NSAttributedString("G", [.font: font,
                                                                      .shadow: shadow])),
                             size: CGSize(width: 1000, height: 1000), displayScale: displayScale,
                             options: nil)
    let imageSize = CGSize(width: 25, height: 25);

    // Draw with (implicit) contextBaseCTM_d:0 parameter into context created by UIKit.
    {
      UIGraphicsBeginImageContextWithOptions(imageSize, true, 2)
      let cgContext = UIGraphicsGetCurrentContext()!
      XCTAssertEqual(CGContextGetBaseCTM(cgContext).d, -2);
      UIColor.white.setFill()
      cgContext.fill(CGRect(origin: .zero, size: imageSize))
      frame.draw()
      let image = UIGraphicsGetImageFromCurrentImageContext()!
      UIGraphicsEndImageContext()
      self.checkSnapshotImage(image);
    }();
    // Draw with explicit contextBaseCTM_d:-2 parameter into context created by UIKit.
    {
      UIGraphicsBeginImageContextWithOptions(imageSize, true, 2)
      let cgContext = UIGraphicsGetCurrentContext()!
      XCTAssertEqual(CGContextGetBaseCTM(cgContext).d, -2);
      UIColor.white.setFill()
      cgContext.fill(CGRect(origin: .zero, size: imageSize))
      frame.draw(in: cgContext, contextBaseCTM_d: -2, pixelAlignBaselines: true)
      let image = UIGraphicsGetImageFromCurrentImageContext()!
      UIGraphicsEndImageContext()
      self.checkSnapshotImage(image);
    }();
    // Draw with explicit contextBaseCTM_d:1 parameter into context created with
    // CoreGraphics function.
    {
      let cgImage = stu_createCGImage(size: imageSize, scale: displayScale,
                                      backgroundColor: UIColor.white.cgColor,
                                      STUCGImageFormat(.rgb, [.withoutAlphaChannel]),
                    { context in
                      XCTAssertEqual(CGContextGetBaseCTM(context).d, 1)
                      frame.draw(in: context, contextBaseCTM_d: 1, pixelAlignBaselines: true)
                    })!
      let image = UIImage(cgImage: cgImage, scale: displayScale, orientation: .up)
      self.checkSnapshotImage(image);
    }();
  }

  func testBaselineRounding() {
    let font = UIFont(name: "HelveticaNeue", size: 18.25)!
    let attributedString = NSAttributedString("L", [.font: font,
                                                    .underlineStyle: NSUnderlineStyle.single.rawValue,
                                                    .backgroundColor: UIColor.red])
    let frame = STUTextFrame(STUShapedString(attributedString),
                             size: CGSize(width: 1000, height: 1000), displayScale: 0,
                             options: STUTextFrameOptions { (b) in b.textLayoutMode = .textKit })
    let layoutBounds = frame.layoutBounds
    let size = CGSize(width: ceil(layoutBounds.maxX + 2), height: ceil(layoutBounds.maxY + 2))
    ({
      UIGraphicsBeginImageContextWithOptions(size, false, 2)
      let cgContext = UIGraphicsGetCurrentContext()!
      XCTAssertEqual(CGContextGetBaseCTM(cgContext).d, -2);
      cgContext.translateBy(x: -1, y: 1)
      frame.draw(at: CGPoint(x: 1.5, y: -0.25))
      let image = UIGraphicsGetImageFromCurrentImageContext()!
      UIGraphicsEndImageContext()
      // If the rounding doesn't work, the horizontal edges of the underline and the background
      // will be aliased.
      self.checkSnapshotImage(image);
    })()

    let scaledFrame = STUTextFrame(STUShapedString(attributedString),
                                   size: CGSize(width: layoutBounds.size.width/2, height: 1000),
                                   displayScale: 0,
                                   options: STUTextFrameOptions { (b) in
                                              b.textLayoutMode = .textKit
                                              b.minimumTextScaleFactor = 0.1
                                            })
    let scaledLayoutBounds = scaledFrame.layoutBounds
    ({
      UIGraphicsBeginImageContextWithOptions(CGSize(width: ceil(scaledLayoutBounds.maxX + 2),
                                                    height: ceil(scaledLayoutBounds.maxY + 2)),
                                             false, 2)
      let cgContext = UIGraphicsGetCurrentContext()!
      XCTAssertEqual(CGContextGetBaseCTM(cgContext).d, -2);
      cgContext.translateBy(x: -1, y: 1)
      scaledFrame.draw(at: CGPoint(x: 1.5, y: -0.25))
      let image = UIGraphicsGetImageFromCurrentImageContext()!
      UIGraphicsEndImageContext()
      // If the rounding doesn't work, the horizontal edges of the underline and the background
      // will be aliased.
      self.checkSnapshotImage(image, suffix: "_scaled");
    })()
  }

  func testDrawingIntoPDFContext() {
    let font = UIFont(name: "HelveticaNeue", size: 18)!
    let attributedString = NSAttributedString("Apple", [.font: font,
                                                        .underlineStyle: NSUnderlineStyle.single.rawValue])
    let frame = STUTextFrame(STUShapedString(attributedString),
                             size: CGSize(width: 1000, height: 1000), displayScale: 0,
                             options: STUTextFrameOptions { (b) in b.textLayoutMode = .textKit })
    let m: CGFloat = 2
    let layoutBounds = frame.layoutBounds
    let size = CGSize(width: ceil(layoutBounds.maxX + 2*m),
                      height: ceil(layoutBounds.maxY + 2*m))
    let data = NSMutableData();
    {
      UIGraphicsBeginPDFContextToData(data, CGRect(origin: .zero, size: size), nil)
      UIGraphicsBeginPDFPage()
      let cgContext = UIGraphicsGetCurrentContext()!
      frame.draw(at: CGPoint(x: m, y: m),
                 in: cgContext, contextBaseCTM_d: 0, pixelAlignBaselines: false)
      UIGraphicsEndPDFContext()
    }();

    let pdfPage = CGPDFDocument(CGDataProvider(data: data)!)!.page(at: 1)!

    // Compare generated PDF with reference by comparing images rendered at a high resolution.

    let pdfCGImage = stu_createCGImage(size: size, scale: -20,
                                       backgroundColor: UIColor.white.cgColor,
                                       STUCGImageFormat(.grayscale, [.withoutAlphaChannel]),
                                       { context in
                                         context.drawPDFPage(pdfPage)
                                       })!

    let pdfImage = UIImage(cgImage: pdfCGImage, scale: 1, orientation: .up)

    let pdfPath = pathRelativeToCurrentSourceDir(
                    "ReferenceImages/TextFrameDrawingTests/testDrawingIntoPDFContext.pdf")
    let referencePDFPage = CGPDFDocument(URL(fileURLWithPath: pdfPath) as CFURL)!
                            .page(at: 1)!
    let referencePDFCGImage = stu_createCGImage(size: size, scale: -20,
                                                backgroundColor: UIColor.white.cgColor,
                                                STUCGImageFormat(.grayscale, [.withoutAlphaChannel]),
                                                { context in
                                                  context.drawPDFPage(referencePDFPage)
                                                })!
    let referencePDFImage = UIImage(cgImage: referencePDFCGImage, scale: 1, orientation: .up)

    self.checkSnapshotImage(pdfImage, referenceImage: referencePDFImage)
  }
}
