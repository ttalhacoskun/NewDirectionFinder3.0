import SwiftUI
import CoreLocation
import MapKit

struct Home: View {
    /// Map Properties
    @State private var cameraPosition: MapCameraPosition = .region(.myRegion)
    @State private var mapSelection: MKMapItem?
    @Namespace private var locationSpace
    @State private var viewingRegion: MKCoordinateRegion?
    /// Search Properties
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
    /// Recommendation Properties
    @State private var recommendations: [String] = []
    
    func calculateDistance() -> String {
        guard let route = route else {
            return ""
        }
        
        let distanceInKilometers = route.distance / 1000.0 // Metreleri kilometreye çevir
        return String(format: "%.2f km", distanceInKilometers)
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    TextField("Burada arayın", text: $searchText, onEditingChanged: { isEditing in
                        if isEditing {
                            fetchRecommendations(for: searchText)
                        }
                    })
                    .textFieldStyle(PlainTextFieldStyle())
                    .padding(8)
                    .background(Color(.systemGray6).opacity(0.8))
                    .cornerRadius(8)
                    
                }
                .padding(.horizontal)
                .onSubmit {
                    Task {
                        guard !searchText.isEmpty else { return }
                        await searchPlaces()
                    }
                }
                
                /// Display Category Buttons
                Map(position: $cameraPosition, selection: $mapSelection, scope: locationSpace) {
                    /// Map Annotations
                    Annotation("My Location", coordinate: .myLocation) {
                        VStack {
                            ZStack {
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
                        .preferredColorScheme(isDarkMode ? .dark : .light)
                        .onAppear {
                            isDarkMode = true
                        }
                        .preferredColorScheme(.dark)
                        .accentColor(.white)
                    }
                    .annotationTitles(.hidden)
                    
                    ForEach(searchResults, id: \.self) { mapItem in
                        if routeDisplaying {
                            if mapItem == routeDestination {
                                let placemark = mapItem.placemark
                                Marker(placemark.name ?? "Place", coordinate: placemark.coordinate)
                            }
                        } else {
                            let placemark = mapItem.placemark
                            Marker(placemark.name ?? "Place", coordinate: placemark.coordinate)
                        }
                    }
                    
                    if let route {
                        MapPolyline(route.polyline)
                            .stroke(.blue, lineWidth: 7)
                    }
                    
                    UserAnnotation()
                }
                .onMapCameraChange { ctx in
                    viewingRegion = ctx.region
                }
                .overlay(alignment: .bottomTrailing) {
                    VStack(spacing: 15) {
                        MapCompass(scope: locationSpace)
                        MapPitchToggle(scope: locationSpace)
                        MapUserLocationButton(scope: locationSpace)
                    }
                    .buttonBorderShape(.circle)
                    .padding()
                }
                .mapScope(locationSpace)
                .sheet(isPresented: $showDetails, onDismiss: {
                    withAnimation(.snappy) {
                        if let boundingRect = route?.polyline.boundingMapRect, routeDisplaying {
                            cameraPosition = .rect(boundingRect)
                        }
                    }
                }, content: {
                    MapDetails()
                        .presentationDetents([.height(350)])
                        .presentationBackgroundInteraction(.enabled(upThrough: .height(350)))
                        .presentationCornerRadius(35)
                        .interactiveDismissDisabled(true)
                })
                .onChange(of: showSearch, initial: false) {
                    if !showSearch {
                        searchResults.removeAll(keepingCapacity: false)
                        showDetails = false
                        withAnimation(.snappy) {
                            cameraPosition = .region(.myRegion)
                        }
                    }
                }
                .onChange(of: mapSelection) { oldValue, newValue in
                    showDetails = newValue != nil
                    fetchLookAroundPreview()
                }
                .overlay(alignment: .bottom) {
                    if routeDisplaying {
                        SnackBar(distance: calculateDistance(), endRouteAction: {
                            withAnimation(.snappy) {
                                routeDisplaying = false
                                showDetails = true
                                mapSelection = routeDestination
                                routeDestination = nil
                                route = nil
                                cameraPosition = .region(.myRegion)
                            }
                        }, openInAppleMaps: {
                            openInMaps(using: .apple)
                        }, openInGoogleMaps: {
                            openInMaps(using: .google)
                        })
                        .padding(.bottom, 20)
                    }
                }
            }
        }
    }
    
    /// Map Details View
    @ViewBuilder
    func MapDetails() -> some View {
        VStack(spacing: 15) {
            ZStack {
                if lookAroundScene == nil {
                    ContentUnavailableView("No Preview Available", systemImage: "eye.slash")
                } else {
                    LookAroundPreview(scene: $lookAroundScene)
                }
            }
            .frame(height: 200)
            .clipShape(.rect(cornerRadius: 15))
            .overlay(alignment: .topTrailing) {
                Button(action: {
                    showDetails = false
                    withAnimation(.snappy) {
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
            
            Button("Get Directions", action: fetchRoute)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(.blue.gradient, in: .rect(cornerRadius: 15))
        }
    }
    
    /// Search Places
    func searchPlaces() async {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = searchText
        request.region = viewingRegion ?? .myRegion
        
        let results = try? await MKLocalSearch(request: request).start()
        searchResults = results?.mapItems ?? []
    }
    
    /// Fetching Location Preview
    func fetchLookAroundPreview() {
        if let mapSelection {
            lookAroundScene = nil
            Task {
                let request = MKLookAroundSceneRequest(mapItem: mapSelection)
                lookAroundScene = try? await request.scene
            }
        }
    }
    
    /// Fetching route
    func fetchRoute() {
        if let mapSelection {
            let request = MKDirections.Request()
            request.source = .init(placemark: .init(coordinate: .myLocation))
            request.destination = mapSelection
            
            Task {
                let result = try? await MKDirections(request: request).calculate()
                route = result?.routes.first
                routeDestination = mapSelection
                
                withAnimation(.snappy) {
                    routeDisplaying = true
                    showDetails = false
                }
            }
        }
    }
    
    /// Fetching recommendations using AI (Mocked for this example)
    func fetchRecommendations(for query: String) {
        // Mocked recommendations
        recommendations = ["Eiffel Tower", "Louvre Museum", "Notre-Dame Cathedral", "Champs-Élysées", "Montmartre"]
    }
    
    /// Function to open in Apple or Google Maps
    func openInMaps(using app: MapApp) {
        guard let destination = routeDestination?.placemark else { return }
        let coordinate = destination.coordinate
        let placeName = destination.name ?? "Destination"
        
        switch app {
        case .apple:
            let mapItem = MKMapItem(placemark: destination)
            mapItem.name = placeName
            mapItem.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
        case .google:
            let url = URL(string: "comgooglemaps://?daddr=\(coordinate.latitude),\(coordinate.longitude)&directionsmode=driving")!
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            } else {
                let webUrl = URL(string: "https://www.google.com/maps/dir/?api=1&destination=\(coordinate.latitude),\(coordinate.longitude)")!
                UIApplication.shared.open(webUrl, options: [:], completionHandler: nil)
            }
        }
    }
}

/// Enum for Map Apps
enum MapApp {
    case apple
    case google
}

/// Custom SnackBar View
struct SnackBar: View {
    let distance: String
    let endRouteAction: () -> Void
    let openInAppleMaps: () -> Void
    let openInGoogleMaps: () -> Void
    
    var body: some View {
        VStack {
            HStack {
                Text("Uzaklık: \(distance)")
                    .foregroundColor(.white)
                Spacer()
                Button(action: openInAppleMaps) {
                    Text("Apple Maps")
                        .foregroundColor(.white)
                        .padding(.horizontal)
                        .background(Color.blue.cornerRadius(8))
                }
                Button(action: openInGoogleMaps) {
                    Text("Google Maps")
                        .foregroundColor(.white)
                        .padding(.horizontal)
                        .background(Color.blue.cornerRadius(7))
                }
                Button("End Route", action: endRouteAction)
                    .foregroundColor(.white)
                    .padding(.horizontal)
                    .background(Color.red.cornerRadius(8))
            }
            .padding()
            .background(Color.black.opacity(0.8).cornerRadius(12))
            .padding(.horizontal)
        }
    }
}

/// Custom Category Button
struct CategoryButton: View {
    let title: String
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack {
                Image(systemName: icon)
                    .foregroundColor(.white)
                    .padding(10)
                    .background(Color.blue)
                    .clipShape(Circle())
                Text(title)
                    .font(.footnote)
                    .foregroundColor(.primary)
            }
            .padding(.horizontal, 10)
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
