//
//  CustomAnnotation.swift
//  IndoorLocation
//
//  Created by Dennis Hirschgänger on 12.05.17.
//  Copyright © 2017 Hirschgaenger. All rights reserved.
//

import MapKit

class CustomAnnotation: MKPointAnnotation {
    var annotationType: AnnotationType
    
    init(_ annotationType: AnnotationType) {
        self.annotationType = annotationType

        super.init()
    }
}
