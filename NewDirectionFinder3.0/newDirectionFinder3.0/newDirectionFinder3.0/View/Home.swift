//
//  Home.swift
//  NewDirectionFinder
//
//  Created by Talha Coşkun on 31.08.2023.
//

import SwiftUI
import CoreLocation
import MapKit
    
    struct Home: View {
        /// Map Properties
        @State private var cameraPosition: MapCameraPosition = .region(.myRegion)
        @State private var mapSelection: MKMapItem?
        @Namespace private var locationSpace
        @State private var viewingRegion: MKCoordinateRegion?
        ///Search Properties
        @State private var searchText: String = ""
        @State private var showSearch: Bool = false
        @State private var searchResults: [MKMapItem] = []
        /// Map Selection Detail Properties
        @State private var showDetails: Bool = false
        @State private var lookAroundScene: MKLookAroundScene?
        /// Route Properties
        @State private var routeDisplaying: Bool = false
        @State private var route: MKRoute?
        @State private var routeDestination: MKMapItem?
        @State private var isDarkMode = false
        
        func calculateDistance() -> String {
            guard let route = route else {
                return "Henüz bir rota seçilmedi."
            }
            
            let distanceInKilometers = route.distance / 1000.0 // Metreleri kilometreye çevir
            return String(format: "%.2f km", distanceInKilometers)
        }
        
        var body: some View {
            
            NavigationStack{
                
                Map(position: $cameraPosition, selection: $mapSelection, scope: locationSpace) {
                    ///Map Annotations
                    Annotation("My Location", coordinate: .myLocation){
                        VStack{
                            ZStack{
                                Circle()
                                    .frame(width: 32, height: 32)
                                    .foregroundStyle(.blue.opacity(0.25))
                                Circle()
                                    .frame(width: 20, height: 20)
                                    .foregroundStyle(.white)
                                Circle()
                                    .frame(width: 12, height: 12)
                                    .foregroundStyle(.blue)
                            }
                        }
                        .preferredColorScheme(isDarkMode ? .dark : .light) // Koyu tema için .dark kullanın
                        .onAppear {
                            // Koyu tema etkinleştirildiğinde
                            isDarkMode = true
                        }
                        .preferredColorScheme(.dark) // Koyu tema etkinleştirildiğinde
                        .accentColor(.white) // Metin ve sembollerin rengi
                    }
                    .annotationTitles(.hidden)
                    
                    /// Simply Display Annotations as Marker, as we seen before
                    ForEach(searchResults, id: \.self) { mapItem in
                        ///Hiding All other Markers, Expect Destionation one
                        if routeDisplaying {
                            if mapItem == routeDestination {
                                let placemark = mapItem.placemark
                                Marker(placemark.name ?? "Place", coordinate: placemark.coordinate)
                            }
                        }else {
                            let placemark = mapItem.placemark
                            Marker(placemark.name ?? "Place", coordinate: placemark.coordinate)
                        }
                    }
                    /// Display Route using Polyline
                    if let route{
                        MapPolyline(route.polyline)
                        ///Applying Bigger Stroke
                            .stroke(.blue, lineWidth: 7)
                    }
                    
                    /// To Show User Current Location
                    UserAnnotation()
                }
                
                .onMapCameraChange ({ ctx in
                    viewingRegion = ctx.region
                })
                .overlay(alignment: .bottomTrailing){
                    VStack(spacing: 15){
                        MapCompass(scope: locationSpace)
                        MapPitchToggle(scope: locationSpace)
                        MapUserLocationButton(scope: locationSpace)
                    }
                    
                    .buttonBorderShape(.circle)
                    .padding()
                }
                
                .mapScope(locationSpace)
                .navigationTitle("Map")
                .navigationBarTitleDisplayMode(.inline)
               
                
                /// Search Bar
                .searchable(text: $searchText, isPresented: $showSearch)
                
                /// Showing Trasnlucent Toolbar
                .toolbarBackground(.visible, for: .navigationBar)
                .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
                /// When route Displaying Hiding Top And Bottom Bar
                .toolbar(routeDisplaying ? .hidden: .visible, for: .navigationBar)
                .sheet(isPresented: $showDetails,onDismiss:{
                    withAnimation(.snappy){
                        /// Zooming Route
                        if let boundingRect = route?.polyline.boundingMapRect, routeDisplaying{
                            cameraPosition = .rect(boundingRect)
                        }
                    }
                },content: {
                    MapDetails()
                        .presentationDetents([.height(350)])
                        .presentationBackgroundInteraction(.enabled(upThrough: .height(350)))
                        .presentationCornerRadius(35)
                        .interactiveDismissDisabled(true)
                    Button(action: {
                                                      }) {
                             HStack {
                                 Image(systemName: "bag.circle.fill")
                                     .resizable()
                                     .frame(width: 20, height: 20)
                                     .padding()
                             }
                         }
                })
                .safeAreaInset(edge: .bottom) {
                    if routeDisplaying {
                        Button("End Route"){
                            /// closing the route and setting the selection
                            withAnimation(.snappy) {
                                routeDisplaying = false
                                showDetails = true
                                mapSelection = routeDestination
                                routeDestination = nil
                                route = nil
                                cameraPosition = .region(.myRegion)
                            }
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(.red.gradient, in: .rect(cornerRadius: 15))
                        .padding()
                        .background(.ultraThinMaterial)
                    }
                }
                Text("Uzaklık: \(calculateDistance())")
                    .font(.headline)
                    .padding()
            }
            .onSubmit(of: .search) {
                Task{
                    guard !searchText.isEmpty else { return }
                    
                    await searchPlaces()
                }
            }
            .onChange(of: showSearch, initial: false) {
                if !showSearch {
                    /// Clearing Search Results
                    searchResults.removeAll(keepingCapacity: false)
                    showDetails = false
                    ///Zooming out to user region when search cancelled
                    withAnimation(.snappy) {
                        cameraPosition = .region(.myRegion)
                    }
                    
                }
            }
            .onChange(of: mapSelection) { oldValue, newValue in
                ///Displaying Details About The Selected Place
                showDetails = newValue != nil
                /// Fetching Look Around Prewiew, when ever selection Changes
                fetchLookAroundPreview()
            }
        }
        
        ///Map Datails View
        @ViewBuilder
        func MapDetails() -> some View {
            VStack(spacing:15){
                ZStack{
                    ///New Look Around API
                    if lookAroundScene == nil {
                        ///New Empty View API
                        ContentUnavailableView("No Preview Available", systemImage:"eye.slash")
                    }else{
                        LookAroundPreview(scene: $lookAroundScene)
                    }
                }
                .frame(height: 200)
                .clipShape(.rect(cornerRadius: 15))
                ///Close Button
                .overlay(alignment: .topTrailing){
                    Button(action: {
                        ///Closing View
                        showDetails = false
                        withAnimation(.snappy){
                            mapSelection = nil
                        }
                    }, label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundStyle(.black)
                            .background(.white, in: .circle)
                    })
                    .padding(10)
                }
                
                ///Direction's Button
                Button("Get Directions",action: fetchRoute)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(.blue.gradient, in: .rect(cornerRadius: 15))
            }
            .padding(15)
        }
        
        /// Search Places
        func searchPlaces()async{
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = searchText
            request.region = viewingRegion ?? .myRegion
            
            let results = try? await MKLocalSearch(request: request).start()
            searchResults = results?.mapItems ?? []
        }
        
        ///Fetching Location Preview
        func fetchLookAroundPreview() {
            if let mapSelection{
                ///Clearing Old One
                lookAroundScene = nil
                Task{
                    let request = MKLookAroundSceneRequest(mapItem: mapSelection)
                    lookAroundScene = try? await request.scene
                }
            }
        }
        /// Fetching route
        func fetchRoute(){
            if let mapSelection {
                let request = MKDirections.Request()
                request.source = .init(placemark: .init(coordinate: .myLocation))
                request.destination = mapSelection
                
                Task{
                    let result = try? await MKDirections(request: request).calculate()
                    route = result?.routes.first
                    /// Saving Route Destination
                    routeDestination = mapSelection
                    
                    withAnimation(.snappy) {
                        routeDisplaying = true
                        showDetails = false
                        
                    }
                }
            }
        }
    }
    
    struct Home_Previews: PreviewProvider {
        static var previews: some View {
            ContentView()
        }
    }
    
    /// Location Data
    extension CLLocationCoordinate2D {
        static var myLocation: CLLocationCoordinate2D {
            return .init(latitude: 37.3346, longitude: -122.0090)
        }
    }
    
    extension MKCoordinateRegion {
        static var myRegion: MKCoordinateRegion {
            return .init(center: .myLocation, latitudinalMeters: 10000, longitudinalMeters: 10000)
        }
    }
