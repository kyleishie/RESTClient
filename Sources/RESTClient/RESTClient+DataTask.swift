//
//  RESTClient+DataTask.swift
//  Swift 4.0
//  Created by Kyle Ishie, Kyle Ishie Development.
//


import Foundation

extension RESTClient {
    
    /**
     Creates a URLDataTask with a preset completion handler capable of decoding the response's body per it's Content-Type header.
     
     Note that this method requires a response body for successful requests.  If it is possible for the body to be nil use dataTask<T : Codable & ExpressibleByNilLiteral>(_:, with:, completionHandler:).
     */
    open func dataTask<T : Decodable>(_ type: T.Type, with request: URLRequest, completionHandler: ((Result<T, Error>) -> Void)? = nil) -> URLSessionDataTask {
        return dataTask(T?.self, with: request, completionHandler: { result in
            switch result {
            case let .success(decoded):
                guard let decoded = decoded else {
                    fatalError("Successful data task decoded nil for expected non-optional type \(type).")
                }
                completionHandler?(.success(decoded))
                
            case let .failure(status, error):
                completionHandler?(.failure(status, error))
                
            case let .systemFailure(error):
                completionHandler?(.systemFailure(error))
            }
        })
    }
    
    /**
     Creates a URLDataTask with a preset completion handler capable of decoding the response's body per it's Content-Type header.
     
     This method allows for the poosibility of a nil response body when the request is successful, however, additional unwrapping is required.
     */
    open func dataTask<T : Decodable & ExpressibleByNilLiteral>(_ type: T.Type, with originalRequest: URLRequest, completionHandler: ((Result<T, Error>) -> Void)? = nil) -> URLSessionDataTask {
        
        var request = originalRequest
        transformers.forEach({ $0.tranform(&request) })
        
        if isLoggingEnabled {
            print("")
            print("headers from session: ", session.configuration.httpAdditionalHeaders ?? "none")
            
            print("")
            print("ORIGINAL REQUEST")
            print("method: ", originalRequest.httpMethod ?? "Unknown")
            print("uri: ", originalRequest)
            print("headers: ", originalRequest.allHTTPHeaderFields ?? "none")
            print("body", originalRequest.httpBody ?? "none")
            
            if let body = originalRequest.httpBody {
                print("Decoded Body", String(data: body, encoding: .utf8) ?? "Could not decode to String")
            }
            
            print("")
            print("MODIFIED REQUEST")
            print("method: ", request.httpMethod ?? "Unknown")
            print("uri: ", request)
            print("headers: ", request.allHTTPHeaderFields ?? "none")
            print("body", request.httpBody ?? "none")
            
            if let body = request.httpBody {
                print("Decoded Body", String(data: body, encoding: .utf8) ?? "Could not decode to String")
            }
        }
        
        var task : URLSessionDataTask? = nil
        task = session.dataTask(with: request) { [decoders, weak self] (data, response, error) in
            
            if self?.isLoggingEnabled == true, let task = task {
                print("")
                print("ORIGINAL REQUEST from TASK")
                print("method: ", task.originalRequest?.httpMethod ?? "Unknown")
                print("uri: ", task.originalRequest ?? "none")
                print("headers: ", task.originalRequest?.allHTTPHeaderFields ?? "none")
                print("body", task.originalRequest?.httpBody ?? "none")
                
                if let body = task.originalRequest?.httpBody {
                    print("Decoded Body", String(data: body, encoding: .utf8) ?? "Could not decode to String")
                }
                
                print("")
                print("MODIFIED REQUEST from TASK")
                print("method: ", task.currentRequest?.httpMethod ?? "Unknown")
                print("uri: ", task.currentRequest ?? "none")
                print("headers: ", task.currentRequest?.allHTTPHeaderFields ?? "none")
                print("body", task.currentRequest?.httpBody ?? "none")
                
                if let body = task.currentRequest?.httpBody {
                    print("Decoded Body", String(data: body, encoding: .utf8) ?? "Could not decode to String")
                }
            }
            
            
            guard let response = response as? HTTPURLResponse else {
                completionHandler?(.systemFailure(error!))
                return
            }
            
            guard let contentType = response.contentType else {
                completionHandler?(.success(nil))
                return
            }
            
            guard let decoder = decoders[contentType] else {
                fatalError("Unable to determine decoder for response content-type")
            }
            
            guard let data = data else {
                completionHandler?(.success(nil))
                return
            }
            
            do {
                
                try response.validate()
                
                let decoded = try decoder.decode(T.self, from: data)
                completionHandler?(.success(decoded))
                
            } catch HTTPURLResponseError.unacceptableStatus(let status) {
                
                do {
                    
                    let decodedAPIError = try decoder.decode(Error.self, from: data)
                    completionHandler?(.failure(status, decodedAPIError))
                    
                } catch {
                    
                    completionHandler?(.systemFailure(error))
                    
                }
                
            } catch {
                
                completionHandler?(.systemFailure(error))
                
            }
        }
        
        return task!
    }
    
    /**
        Creates and Performs a URLSessionDataTask with a preset completion handler capable of decoding the response's body per it's Content-Type header.
     
        Note that this method blocks until the task completes and calls it's completion handler at which time a value may be returned or an error may be thrown.
    */
    open func performSyncDataTask<T : Decodable>(_ type: T.Type, with request: URLRequest) throws -> T? {
        
        var res : Result<T, Error>? = nil
        
        let semaphore = DispatchSemaphore(value: 0)
        
        let task = dataTask(T.self, with: request) { r in
            defer { semaphore.signal() }
            res = r
        }
        
        task.resume()
        semaphore.wait()
        
        guard let result = res else {
            return nil
        }
        
        guard case let .success(object) = result else {
            guard case let .failure(status, error) = result else {
                return nil
            }
            print("Status --> \(status)")
            throw error
        }
        
        return object
    }
    
}

