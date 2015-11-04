//
//  The MIT License (MIT)
//
//  Copyright (c) 2015 Srdan Rasic (@srdanrasic)
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

public protocol ObservableCollectionType: CollectionType, StreamType {
  typealias Collection: CollectionType
  typealias Index = Collection.Index
  
  var collection: Collection { get }
  mutating func dispatch(event: ObservableCollectionEvent<Collection>)
  
  func observe(on context: ExecutionContext, sink: ObservableCollectionEvent<Collection> -> ()) -> DisposableType
}

public class ObservableCollection<Collection: CollectionType>: ActiveStream<ObservableCollectionEvent<Collection>>, ObservableCollectionType {
  
  public private(set) var collection: Collection {
    get {
      return try! lastEvent().collection
    }
    set {
      dispatch(ObservableCollectionEvent(collection: newValue, inserts: [], deletes: [], updates: []))
    }
  }
  
  private var capturedSink: (ObservableCollectionEvent<Collection> -> ())? = nil
  
  public convenience init(_ collection: Collection) {
    var capturedSink: (ObservableCollectionEvent<Collection> -> ())!
    
    self.init() { sink in
      capturedSink = sink
      sink(ObservableCollectionEvent.initial(collection))
      return nil
    }
    
    self.capturedSink = capturedSink
  }
  
  public init(@noescape producer: (ObservableCollectionEvent<Collection> -> ()) -> DisposableType?) {
    super.init(limit: 1, producer: { sink in
      return producer(sink)
    })
  }
  
  public func dispatch(event: ObservableCollectionEvent<Collection>) {
    capturedSink?(event)
  }
  
  // MARK: CollectionType conformance
  
  public func generate() -> Collection.Generator {
    return collection.generate()
  }
  
  public func underestimateCount() -> Int {
    return collection.underestimateCount()
  }
  
  public var startIndex: Collection.Index {
    return collection.startIndex
  }
  
  public var endIndex: Collection.Index {
    return collection.endIndex
  }
  
  public var isEmpty: Bool {
    return collection.isEmpty
  }
  
  public var count: Collection.Index.Distance {
    return collection.count
  }
  
  public subscript(index: Collection.Index) -> Collection.Generator.Element {
    get {
      return collection[index]
    }
  }
}

@warn_unused_result
public func create<C: CollectionType>(producer: (ObservableCollectionEvent<C> -> ()) -> DisposableType?) -> ObservableCollection<C> {
  return ObservableCollection(producer: producer)
}

public extension ObservableCollectionType {
  
  @warn_unused_result
  public func zipPrevious() -> Observable<(ObservableCollectionEvent<Collection>?, ObservableCollectionEvent<Collection>)> {
    return create { sink in
      var previous: ObservableCollectionEvent<Collection>? = nil
      return self.observe(on: ImmediateExecutionContext) { event in
        sink(previous, event)
        previous = event
      }
    }
  }
}

public extension ObservableCollectionType where Collection.Index == Int {
  
  /// Each event costs O(n)
  @warn_unused_result
  public func map<U>(transform: Collection.Generator.Element -> U) -> ObservableCollection<Array<U>> {
    return create { sink in
      return self.observe(on: ImmediateExecutionContext) { event in
        sink(event.map(transform))
      }
    }
  }
}

public extension ObservableCollectionType where Collection.Index == Int {
  
  /// Each event costs O(n)
  @warn_unused_result
  public func filter(include: Collection.Generator.Element -> Bool) -> ObservableCollection<Array<Collection.Generator.Element>> {
    return create { sink in
      return self.observe(on: ImmediateExecutionContext) { event in
        sink(event.filter(include))
      }
    }
  }
}

public extension ObservableCollectionType where Collection.Index: Hashable {
  
  /// Each event costs O(n*logn)
  @warn_unused_result
  public func sort(isOrderedBefore: (Collection.Generator.Element, Collection.Generator.Element) -> Bool) -> ObservableCollection<Array<Collection.Generator.Element>> {
    return create { sink in
      return self.observe(on: ImmediateExecutionContext) { event in
        sink(event.sort(isOrderedBefore))
      }
    }
  }
}

public extension ObservableCollectionType where Collection.Index: Equatable {
  
  /// Each event costs O(n^2)
  @warn_unused_result
  public func sort(isOrderedBefore: (Collection.Generator.Element, Collection.Generator.Element) -> Bool) -> ObservableCollection<Array<Collection.Generator.Element>> {
    return create { sink in
      return self.observe(on: ImmediateExecutionContext) { event in
        sink(event.sort(isOrderedBefore))
      }
    }
  }
}
