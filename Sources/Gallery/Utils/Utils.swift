import UIKit
import AVFoundation
import Photos

struct Utils {

  static func rotationTransform() -> CGAffineTransform {
    switch UIDevice.current.orientation {
    case .landscapeLeft:
      return CGAffineTransform(rotationAngle: CGFloat(Double.pi/2))
    case .landscapeRight:
      return CGAffineTransform(rotationAngle: CGFloat(-Double.pi/2))
    case .portraitUpsideDown:
      return CGAffineTransform(rotationAngle: CGFloat(Double.pi))
    default:
      return CGAffineTransform.identity
    }
  }

  static func videoOrientation() -> AVCaptureVideoOrientation {
    switch UIDevice.current.orientation {
    case .portrait:
      return .portrait
    case .landscapeLeft:
      return .landscapeRight
    case .landscapeRight:
      return .landscapeLeft
    case .portraitUpsideDown:
      return .portraitUpsideDown
    default:
      return .portrait
    }
  }

  static func fetchOptions() -> PHFetchOptions {
    let options = PHFetchOptions()
    options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]

    return options
  }

  static func format(_ duration: TimeInterval) -> String {
    let formatter = DateComponentsFormatter()
    formatter.zeroFormattingBehavior = .pad

    if duration >= 3600 {
      formatter.allowedUnits = [.hour, .minute, .second]
    } else {
      formatter.allowedUnits = [.minute, .second]
    }

    return formatter.string(from: duration) ?? ""
  }
  
    static func getImageWithColor(color: UIColor, size: CGSize) -> UIImage {
        let rect = CGRect(origin: CGPoint(x: 0, y: 0), size: CGSize(width: size.width, height: size.height))
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        color.setFill()
        UIRectFill(rect)
        let image: UIImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return image
    }
  
    static func textFontAttributes(_ width: CGFloat) -> [NSAttributedString.Key: Any] {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = .byWordWrapping
        let textFontAttributes = [
            NSAttributedString.Key.font: UIFont(name: "Helvetica", size: width * 0.05),
            NSAttributedString.Key.foregroundColor: UIColor.white,
            NSAttributedString.Key.backgroundColor: UIColor.clear,
            NSAttributedString.Key.strokeWidth: -1,
            NSAttributedString.Key.strokeColor: UIColor.black,
            NSAttributedString.Key.paragraphStyle: paragraphStyle
        ] as [NSAttributedString.Key : Any]
        return textFontAttributes
    }
    
    static func textToImage(drawText: NSString, inImage: UIImage? = nil, targetSize: CGSize? = CGSize.zero) -> UIImage? {

        if inImage == nil && targetSize == CGSize.zero {
            return nil
        }
        var tmpimg: UIImage?
        if targetSize == CGSize.zero {
            tmpimg = inImage
        } else {
            tmpimg = getImageWithColor(color: UIColor.clear, size: targetSize!)
        }

        guard let img = tmpimg else {
            return nil
        }

        let imageSize = img.size
        let scale: CGFloat = 0
        UIGraphicsBeginImageContextWithOptions(imageSize, false, scale)

        // Put the image into a rectangle as large as the original image
        img.draw(in: CGRect.init(x: 0, y: 0, width: imageSize.width, height: imageSize.height))

        // Create a point within the space that is as bit as the image
        let rect = CGRect.init(x: 0, y: 0, width: imageSize.width * 0.7, height: imageSize.width * 0.3)

        // Draw the text into an image
        drawText.draw(in: rect, withAttributes: Utils.textFontAttributes(imageSize.width))

        // Create a new image out of the images we have created
        var newImage = UIGraphicsGetImageFromCurrentImageContext()

        // End the context now that we have the image we need
        UIGraphicsEndImageContext()

        //Pass the image back up to the caller
        return newImage

    }

}
