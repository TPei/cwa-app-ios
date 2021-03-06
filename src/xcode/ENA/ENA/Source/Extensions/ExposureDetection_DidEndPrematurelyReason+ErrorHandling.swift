//
// Corona-Warn-App
//
// SAP SE and all other contributors
// copyright owners license this file to you under the Apache
// License, Version 2.0 (the "License"); you may not use this
// file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.
//

import UIKit
import ExposureNotification

extension ExposureDetection.DidEndPrematurelyReason {
	func errorAlertController(rootController: UIViewController) -> UIAlertController? {
		switch self {
		case let .noSummary(error):
			return makeAlertControllerForENError(error, rootController: rootController)
		case .noDiskSpace:
			return rootController.setupErrorAlert(
				message: localizedDescription
			)
		default:
			// Don't show an alert for all other errors.
			return nil
		}
	}

	private func makeAlertControllerForENError(_ error: Error?, rootController: UIViewController) -> UIAlertController {
		switch error {
		case let error as ENError:
			let openFAQ: (() -> Void)? = {
				guard let url = error.faqURL else { return nil }
				return {
					UIApplication.shared.open(url, options: [:])
				}
			}()
			return rootController.setupErrorAlert(
				message: localizedDescription,
				secondaryActionTitle: AppStrings.Common.errorAlertActionMoreInfo,
				secondaryActionCompletion: openFAQ
			)
		default:
			return rootController.setupErrorAlert(
				message: localizedDescription
			)
		}
	}
}
