// RoamTests/CityResolverTests.swift
import Testing
import CoreLocation
@testable import Roam

struct CityResolverTests {

    @Test func coordinateCacheReturnsHitWithin5km() {
        let cache = CoordinateCache()
        cache.store(
            latitude: 45.5152, longitude: -122.6784,
            city: "Portland", region: "OR", country: "US"
        )
        let result = cache.lookup(latitude: 45.5200, longitude: -122.6784)
        #expect(result != nil)
        #expect(result?.city == "Portland")
    }

    @Test func coordinateCacheReturnsMissBeyond5km() {
        let cache = CoordinateCache()
        cache.store(
            latitude: 45.5152, longitude: -122.6784,
            city: "Portland", region: "OR", country: "US"
        )
        let result = cache.lookup(latitude: 37.7749, longitude: -122.4194)
        #expect(result == nil)
    }

    @Test func coordinateCacheHandlesMultipleCities() {
        let cache = CoordinateCache()
        cache.store(latitude: 45.5152, longitude: -122.6784, city: "Portland", region: "OR", country: "US")
        cache.store(latitude: 37.7749, longitude: -122.4194, city: "San Francisco", region: "CA", country: "US")

        let portland = cache.lookup(latitude: 45.5100, longitude: -122.6800)
        #expect(portland?.city == "Portland")

        let sf = cache.lookup(latitude: 37.7800, longitude: -122.4200)
        #expect(sf?.city == "San Francisco")
    }
}
