//
//  FloorplanOverlayRenderer.swift
//  IndoorLocation
//
//  Created by Dennis Hirschgänger on 30/03/2017.
//  Copyright © 2017 Hirschgaenger. All rights reserved.
//

import Foundation
import MapKit

/**
 This class draws your FloorplanOverlay into an MKMapView.
 It is also capable of drawing diagnostic visuals to help with debugging,
 if needed.
 */
class FloorplanOverlayRenderer: MKOverlayRenderer {
    
    override init(overlay: MKOverlay) {
        super.init(overlay: overlay)
    }
    
    /**
     - note: Overrides the drawMapRect method for MKOverlayRenderer.
     */
    override func draw(_ mapRect: MKMapRect, zoomScale: MKZoomScale, in context: CGContext) {
        assert(overlay.isKind(of: FloorplanOverlay.self), "Wrong overlay type")
        
        let floorplanOverlay = overlay as! FloorplanOverlay
        
        let boundingMapRect = overlay.boundingMapRect
        
        /*
         Mapkit converts to its own dynamic CGPoint frame, which we can read
         through rectForMapRect.
         */
        let mapkitToGraphicsConversion = rect(for: boundingMapRect)
        
        let graphicsFloorplanCenter = CGPoint(x: mapkitToGraphicsConversion.midX, y: mapkitToGraphicsConversion.midY)
        let graphicsFloorplanWidth = mapkitToGraphicsConversion.width
        let graphicsFloorplanHeight = mapkitToGraphicsConversion.height
        
        // Now, how does this compare to MapKit coordinates?
        let mapkitFloorplanCenter = MKMapPoint(x: MKMapRectGetMidX(overlay.boundingMapRect), y: MKMapRectGetMidY(overlay.boundingMapRect))
        
        let mapkitFloorplanWidth = MKMapRectGetWidth(overlay.boundingMapRect)
        let mapkitFloorplanHeight = MKMapRectGetHeight(overlay.boundingMapRect)
        
        /*
         Create the transformation that converts to Graphics coordinates from
         MapKit coordinates.
         
         graphics.x = (mapkit.x - mapkitFloorplanCenter.x) *
         graphicsFloorplanWidth / mapkitFloorplanWidth
         + graphicsFloorplanCenter.x
         */
        var fromMapKitToGraphics = CGAffineTransform.identity as CGAffineTransform
        
        fromMapKitToGraphics = fromMapKitToGraphics.translatedBy(x: CGFloat(-mapkitFloorplanCenter.x), y: CGFloat(-mapkitFloorplanCenter.y))
        fromMapKitToGraphics = fromMapKitToGraphics.scaledBy(x: graphicsFloorplanWidth / CGFloat(mapkitFloorplanWidth),
                                                             y: graphicsFloorplanHeight / CGFloat(mapkitFloorplanHeight)
        )
        fromMapKitToGraphics = fromMapKitToGraphics.translatedBy(x: graphicsFloorplanCenter.x, y: graphicsFloorplanCenter.y)
        
        /*
         However, we want to be able to send draw commands in the original
         PDF coordinates though, so we'll also need the transformations that
         convert to MapKit coordinates from PDF coordinates.
         */
        let fromPDFToMapKit = floorplanOverlay.transformerFromPDFToMk
        
        context.concatenate(fromPDFToMapKit.concatenating(fromMapKitToGraphics))
        
        context.drawPDFPage(floorplanOverlay.pdfPage)
    }
}
