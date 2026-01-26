//
//  OpenPetFoodFactsService.swift
//  FitCat
//
//  Service for querying Open Pet Food Facts API
//

import Foundation

// MARK: - API Response Models
struct OpenPetFoodFactsResponse: Codable {
    let status: Int
    let product: OpenPetFoodFactsProduct?
}

struct OpenPetFoodFactsProduct: Codable {
    let productName: String?
    let brands: String?
    let nutriments: Nutriments?
    let categoriesTags: [String]?

    enum CodingKeys: String, CodingKey {
        case productName = "product_name"
        case brands
        case nutriments
        case categoriesTags = "categories_tags"
    }
}

struct Nutriments: Codable {
    let proteins100g: Double?
    let fat100g: Double?
    let fiber100g: Double?
    let moisture100g: Double?
    let ash100g: Double?

    enum CodingKeys: String, CodingKey {
        case proteins100g = "proteins_100g"
        case fat100g = "fat_100g"
        case fiber100g = "fiber_100g"
        case moisture100g = "moisture_100g"
        case ash100g = "ash_100g"
    }
}

// MARK: - Service
class OpenPetFoodFactsService: NSObject {
    private let baseURL = "https://world.openpetfoodfacts.org/api/v2/product"
    private let writeURL = "https://world.openpetfoodfacts.org/cgi/product_jqm2.pl"

    // Credentials from config file
    private let apiUsername = APIConfig.openPetFoodFactsUsername
    private let apiPassword = APIConfig.openPetFoodFactsPassword

    private var isSimulator: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }

    private lazy var session: URLSession = {
        #if DEBUG
        let config = URLSessionConfiguration.default
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
        #else
        return URLSession.shared
        #endif
    }()

    func fetchProduct(barcode: String) async throws -> Product? {
        let urlString = "\(baseURL)/\(barcode).json"

        guard let url = URL(string: urlString) else {
            throw OpenPetFoodFactsError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("FitCat/1.0", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenPetFoodFactsError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw OpenPetFoodFactsError.httpError(statusCode: httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        let apiResponse = try decoder.decode(OpenPetFoodFactsResponse.self, from: data)

        guard apiResponse.status == 1, let product = apiResponse.product else {
            return nil
        }

        return convertToProduct(apiProduct: product, barcode: barcode)
    }

    func uploadProduct(_ product: Product) async throws -> Bool {
        guard let barcode = product.barcode else {
            throw OpenPetFoodFactsError.missingBarcode
        }

        if isSimulator {
            print("📱 SIMULATOR MODE - API Request (POST)")
            print("URL: \(writeURL)")
            print("Method: POST")
            print("Content-Type: multipart/form-data")
            print("User-Agent: FitCat/1.0")
            print("---")
            print("Credentials:")
            print("  user_id: \(apiUsername)")
            print("  password: [HIDDEN]")
            print("---")
            print("Product Data:")
            print("  barcode: \(barcode)")
            print("  product_name: \(product.productName)")
            print("  brands: \(product.brand)")
            print("  nutriment_proteins_100g: \(product.protein)")
            print("  nutriment_fat_100g: \(product.fat)")
            print("  nutriment_fiber_100g: \(product.fiber)")
            print("  nutriment_moisture_100g: \(product.moisture)")
            print("  nutriment_ash_100g: \(product.ash)")
            print("---")
            print("✅ Simulating: Upload successful")
            print("========================================")
            return true
        }

        guard let url = URL(string: writeURL) else {
            throw OpenPetFoodFactsError.invalidURL
        }

        // Create multipart form data
        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("FitCat/1.0", forHTTPHeaderField: "User-Agent")

        var body = Data()

        // Add credentials
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"user_id\"\r\n\r\n")
        body.append("\(apiUsername)\r\n")

        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"password\"\r\n\r\n")
        body.append("\(apiPassword)\r\n")

        // Add barcode
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"code\"\r\n\r\n")
        body.append("\(barcode)\r\n")

        // Add product name
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"product_name\"\r\n\r\n")
        body.append("\(product.productName)\r\n")

        // Add brand
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"brands\"\r\n\r\n")
        body.append("\(product.brand)\r\n")

        // Add nutrition values
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"nutriment_proteins_100g\"\r\n\r\n")
        body.append("\(product.protein)\r\n")

        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"nutriment_fat_100g\"\r\n\r\n")
        body.append("\(product.fat)\r\n")

        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"nutriment_fiber_100g\"\r\n\r\n")
        body.append("\(product.fiber)\r\n")

        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"nutriment_moisture_100g\"\r\n\r\n")
        body.append("\(product.moisture)\r\n")

        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"nutriment_ash_100g\"\r\n\r\n")
        body.append("\(product.ash)\r\n")

        // Close boundary
        body.append("--\(boundary)--\r\n")

        request.httpBody = body

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenPetFoodFactsError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw OpenPetFoodFactsError.httpError(statusCode: httpResponse.statusCode)
        }

        // Parse response
        let decoder = JSONDecoder()
        let uploadResponse = try decoder.decode(UploadResponse.self, from: data)

        return uploadResponse.status == 1
    }

    private func convertToProduct(apiProduct: OpenPetFoodFactsProduct, barcode: String) -> Product? {
        guard let nutriments = apiProduct.nutriments else {
            return nil
        }

        // Require at least protein and fat to be present
        guard let protein = nutriments.proteins100g,
              let fat = nutriments.fat100g else {
            return nil
        }

        let productName = apiProduct.productName ?? "Unknown Product"
        let brand = apiProduct.brands?.split(separator: ",").first.map(String.init) ?? "Unknown Brand"

        // Use 0 as default for missing nutrition values
        let fiber = nutriments.fiber100g ?? 0
        let moisture = nutriments.moisture100g ?? 0
        let ash = nutriments.ash100g ?? 0

        return Product(
            id: UUID(),
            barcode: barcode,
            productName: productName,
            brand: brand,
            protein: protein,
            fat: fat,
            fiber: fiber,
            moisture: moisture,
            ash: ash,
            servingSize: nil,
            createdAt: Date(),
            updatedAt: Date(),
            source: .openpetfoodfacts,
            categoriesTags: apiProduct.categoriesTags
        )
    }
}

// MARK: - Upload Response
struct UploadResponse: Codable {
    let status: Int
    let statusVerbose: String?

    enum CodingKeys: String, CodingKey {
        case status
        case statusVerbose = "status_verbose"
    }
}

// MARK: - Errors
enum OpenPetFoodFactsError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int)
    case missingCredentials
    case missingBarcode

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let statusCode):
            return "HTTP error: \(statusCode)"
        case .missingCredentials:
            return "API credentials not configured. Please add them in Settings."
        case .missingBarcode:
            return "Product must have a barcode to upload"
        }
    }
}

// MARK: - URLSession Delegate (Debug SSL bypass)
#if DEBUG
extension OpenPetFoodFactsService: URLSessionDelegate {
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        // In debug builds, bypass SSL validation for corporate proxies
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust {
            if let serverTrust = challenge.protectionSpace.serverTrust {
                let credential = URLCredential(trust: serverTrust)
                print("⚠️ DEBUG: Bypassing SSL certificate validation")
                completionHandler(.useCredential, credential)
                return
            }
        }
        completionHandler(.performDefaultHandling, nil)
    }
}
#endif

// MARK: - Data Extension
extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}
