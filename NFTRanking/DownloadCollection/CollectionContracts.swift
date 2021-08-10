//
//  CollectionContracts.swift
//  NFTY
//
//  Created by Varun Kohli on 8/8/21.
//

import Foundation

import Web3
import Web3PromiseKit
import Web3ContractABI
import Cache


class UrlCollectionContract : ContractInterface {
  
  private var imageCache : DiskStorage<BigUInt,Data>
  
  let name : String
  let contractAddressHex : String
  let baseUri : String
  
  var tradeActions: TokenTradeInterface?
  
  init(name:String,address:String,baseUri:String) {
    self.imageCache = try! DiskStorage<BigUInt, UIImage>(
      config: DiskConfig(name: "\(name).ImageCache",expiry: .never),
      transformer: TransformerFactory.forImage())
    self.name = name
    self.contractAddressHex = address
    self.ethContract = Erc721Contract(address:address)
    self.baseUri = baseUri
    self.tradeActions = OpenSeaTradeApi(contract: try! EthereumAddress(hex: contractAddressHex, eip55: false))
  }
  
  func getEventsFetcher(_ tokenId: UInt) -> TokenEventsFetcher? {
    return ethContract.getEventsFetcher(tokenId)
  }
  
  func image(_ tokenId:BigUInt) -> Promise<Data?> {
    return Promise { seal in
      var request = URLRequest(url:URL(string:"\(self.baseUri)\(tokenId)")!)
      request.httpMethod = "GET"
      URLSession.shared.dataTask(with: request,completionHandler:{ data, response, error -> Void in
        // print(data,response,error)
        seal.fulfill(data)
      }).resume()
    }
  }
  
  private func download(_ tokenId:BigUInt) -> ObservablePromise<Data?> {
    return ObservablePromise(promise: Promise { seal in
      DispatchQueue.global(qos:.userInteractive).async {
        switch(try? self.imageCache.object(forKey:tokenId)) {
        case .some(let data):
          seal.fulfill(data)
        case .none:
          self.image(tokenId)
            .done(on:DispatchQueue.global(qos: .userInteractive)) {
              seal.fulfill(UrlCollectionContract.imageOfData($0))
            }
            .catch {
              print($0)
              seal.fulfill(nil)
            }
        }
      }
    }) { image in
      DispatchQueue.global(qos:.userInteractive).async {
        image.flatMap {
          try? self.imageCache.setObject($0.image, forKey: tokenId)
        }
      }
    }
  }
  
  func getRecentTrades(onDone: @escaping () -> Void,_ response: @escaping (NFTWithPrice) -> Void) {
    return ethContract.transfer.fetch(onDone:onDone) { log in
      
      let res = try! web3.eth.abi.decodeLog(event:self.ethContract.Transfer,from:log);
      let tokenId = UInt(res["tokenId"] as! BigUInt);
      
      response(NFTWithPrice(
        nft:NFT(
          address:self.contractAddressHex,
          tokenId:tokenId,
          name:self.name,
          media:.ipfsImage(Media.IpfsImageLazy(tokenId:BigUInt(tokenId), download: self.download))),
        blockNumber: log.blockNumber?.quantity,
        indicativePriceWei:.lazy(
          ObservablePromise(
            promise:
              self.ethContract.eventOfTx(transactionHash:log.transactionHash,eventType:.bought)
              .map {
                let price = priceIfNotZero($0?.value);
                return NFTPriceStatus.known(
                  NFTPriceInfo(
                    price:price,
                    blockNumber:log.blockNumber?.quantity,
                    type: price.map { _ in TradeEventType.bought } ?? TradeEventType.transfer))
              }
          ))
      ))
    }
  }
  
  func refreshLatestTrades(onDone: @escaping () -> Void,_ response: @escaping (NFTWithPrice) -> Void) {
    return ethContract.transfer.updateLatest(onDone:onDone) { index,log in
      let res = try! web3.eth.abi.decodeLog(event:self.ethContract.Transfer,from:log);
      let tokenId = UInt(res["tokenId"] as! BigUInt);
      
      let image = Media.IpfsImageLazy(tokenId:BigUInt(tokenId), download: self.download)
      if (index < 2) {
        image.image.load()
      }
      
      response(NFTWithPrice(
        nft:NFT(
          address:self.contractAddressHex,
          tokenId:tokenId,
          name:self.name,
          media:.ipfsImage(image)),
        blockNumber: log.blockNumber?.quantity,
        indicativePriceWei:.lazy(
          ObservablePromise(
            promise:
              self.ethContract.eventOfTx(transactionHash:log.transactionHash,eventType:.bought)
              .map {
                let price = priceIfNotZero($0?.value);
                return NFTPriceStatus.known(
                  NFTPriceInfo(
                    price:price,
                    blockNumber:log.blockNumber?.quantity,
                    type: price.map { _ in TradeEventType.bought } ?? TradeEventType.transfer))
              }
          ))
      ))
    }
  }
  
  func getToken(_ tokenId: UInt) -> Promise<NFTWithLazyPrice> {
    
    Promise.value(
      NFTWithLazyPrice(
        nft:NFT(
          address:self.contractAddressHex,
          tokenId:tokenId,
          name:self.name,
          media:.ipfsImage(Media.IpfsImageLazy(tokenId:BigUInt(tokenId), download: self.download))),
        getPrice: {
          switch(self.ethContract.pricesCache[tokenId]) {
          case .some(let p):
            return p
          case .none:
            let tokenIdTopic = try! ABI.encodeParameter(SolidityWrappedValue.uint(BigUInt(tokenId)))
            let transerFetcher = LogsFetcher(
              event:self.ethContract.Transfer,
              fromBlock:self.ethContract.initFromBlock,
              address:self.contractAddressHex,
              indexedTopics: [nil,nil,tokenIdTopic],
              blockDecrements: 10000)
            
            let p =
              self.ethContract.getTokenHistory(tokenId,fetcher:transerFetcher,retries:30)
              .map(on:DispatchQueue.global(qos:.userInteractive)) { (event:TradeEventStatus) -> NFTPriceStatus in
                switch(event) {
                case .trade(let event):
                  return NFTPriceStatus.known(NFTPriceInfo(price:priceIfNotZero(event.value),blockNumber:event.blockNumber.quantity,type:event.type))
                case .notSeenSince(let since):
                  return NFTPriceStatus.notSeenSince(since)
                }
              }
            let observable = ObservablePromise(promise: p)
            DispatchQueue.main.async {
              self.ethContract.pricesCache[tokenId] = observable
            }
            return observable
          }
        }
      )
    );
  }
  
  func getOwnerTokens(address: EthereumAddress, onDone: @escaping () -> Void, _ response: @escaping (NFTWithLazyPrice) -> Void) {
    ethContract.ethContract.balanceOf(address:address)
      .then(on:DispatchQueue.global(qos: .userInteractive)) { tokensNum -> Promise<Void> in
        if (tokensNum <= 0) {
          return Promise.value(())
        } else {
          return when(
            fulfilled:
              Array(0...tokensNum-1).map { index -> Promise<Void> in
                return
                  self.ethContract.ethContract.tokenOfOwnerByIndex(address: address,index:index)
                  .then { tokenId in
                    return self.getToken(UInt(tokenId))
                  }.done {
                    response($0)
                  }
              }
          )
        }
      }.done(on:DispatchQueue.global(qos:.userInteractive)) { (promises:Void) -> Void in
        onDone()
      }.catch {
        print ($0)
        onDone()
      }
  }
  
  func ownerOf(_ tokenId: UInt) -> Promise<EthereumAddress?> {
    return ethContract.ownerOf(tokenId)
  }
  
}
