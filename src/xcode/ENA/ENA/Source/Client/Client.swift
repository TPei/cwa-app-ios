//
//  Client.swift
//  ENA
//
//  Created by Bormeth, Marc on 05.05.20.
//

import Foundation
import ExposureNotification

/// Describes how to interfact with the backend.
protocol Client {
    // MARK: Types
    typealias Failure = URLSession.Response.Failure
    typealias SubmitKeysCompletionHandler = (SubmissionError?) -> Void
    typealias AvailableDaysCompletionHandler = (Result<[String], Failure>) -> Void
    typealias AvailableHoursCompletionHandler = (Result<[Int], Failure>) -> Void
    typealias DayCompletionHandler = (Result<SAPKeyPackage, Failure>) -> Void
    typealias HourCompletionHandler = (Result<SAPKeyPackage, Failure>) -> Void

    // MARK: Interacting with a Client
    
    /// Determines days that can be downloaded.
    func availableDays(
        completion: @escaping AvailableDaysCompletionHandler
    )

    /// Determines hours that can be downloaded for a given day.
    func availableHours(
        day: String,
        completion: @escaping AvailableHoursCompletionHandler
    )

    /// Fetches the keys for a given `day`.
    func fetchDay(
        _ day: String,
        completion: @escaping DayCompletionHandler
    )

    /// Fetches the keys for a given `hour` of a specific `day`.
    func fetchHour(
        _ hour: Int,
        day: String,
        completion: @escaping HourCompletionHandler
    )

    // MARK: Getting the Configuration
    typealias ExposureConfigurationCompletionHandler = (ENExposureConfiguration?) -> Void

    /// Gets the remove exposure configuration. See `ENExposureConfiguration` for more details
    /// Parameters:
    /// - completion: Will be called with the remove configuration or an error if something went wrong. The completion handler will always be called on the main thread.
    func exposureConfiguration(
        completion: @escaping ExposureConfigurationCompletionHandler
    )

    /// Submits exposure keys to the backend. This makes the local information available to the world so that the risk of others can be calculated on their local devices.
    /// Parameters:
    /// - keys: An array of `ENTemporaryExposureKey`s  to submit to the backend.
    /// - tan: A transaction number
    func submit(
        keys: [ENTemporaryExposureKey],
        tan: String,
        completion: @escaping SubmitKeysCompletionHandler
    )
}

enum SubmissionError: Error {
    case other(Error?)
    case invalidPayloadOrHeaders
    case invalidTan
}

struct DaysResult {
    let errors: [Client.Failure]
    let bucketsByDay: [String: SAPKeyPackage]
}

struct HoursResult {
    let errors: [Client.Failure]
    let bucketsByHour: [Int: SAPKeyPackage]
    let day: String
}

struct FetchedDaysAndHours {
    let hours: HoursResult
    let days: DaysResult
}

extension Client {
    typealias FetchHoursCompletionHandler = (HoursResult) -> Void

    func fetchDays(
        _ days: [String],
        completion completeWith: @escaping (DaysResult) -> Void
    ) {
        var errors = [Client.Failure]()
        var buckets =  [String: SAPKeyPackage]()

        let group = DispatchGroup()
        
        for day in days {
            group.enter()
            fetchDay(day) { result in
                switch result {
                case .success(let bucket):
                    buckets[day] = bucket
                case .failure(let error):
                    errors.append(error)
                }
                group.leave()
            }
        }

        group.notify(queue: .main) {
            completeWith(
                DaysResult(
                    errors: errors,
                    bucketsByDay: buckets
                )
            )
        }
    }

    func fetchHours(
        _ hours: [Int],
        day: String,
        completion completeWith: @escaping FetchHoursCompletionHandler
    ) {
        var errors = [Client.Failure]()
        var buckets = [Int: SAPKeyPackage]()
        let group = DispatchGroup()

        hours.forEach { hour in
            group.enter()
            self.fetchHour(hour, day: day) { result in
                switch result {
                case .success(let hourBucket):
                    buckets[hour] = hourBucket
                case .failure(let error):
                    errors.append(error)
                }
                group.leave()
            }
        }

        group.notify(queue: .main) {
            completeWith(
                HoursResult(errors: errors, bucketsByHour: buckets, day: day)
            )
        }
    }

    typealias DaysAndHoursCompletionHandler = (FetchedDaysAndHours) -> Void

    func fetchDays(
        _ days: [String],
        hours: [Int],
        of day: String,
        completion completeWith: @escaping DaysAndHoursCompletionHandler
    ) {
        let group = DispatchGroup()
        var hoursResult = HoursResult(errors: [], bucketsByHour: [:], day: day)
        var daysResult = DaysResult(errors: [], bucketsByDay: [:])

        group.enter()
        fetchDays(days) { result in
            daysResult = result
            group.leave()
        }

        group.enter()
        fetchHours(hours, day: day) { result in
            hoursResult = result
            group.leave()
        }
        group.notify(queue: .main) {
            completeWith(FetchedDaysAndHours(hours: hoursResult, days: daysResult))
        }
    }
}
