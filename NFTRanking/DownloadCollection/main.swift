//
//  main.swift
//  DownloadCollection
//
//  Created by Varun Kohli on 7/21/21.
//

import Foundation
import PromiseKit
import BigInt
import Web3
import Web3ContractABI

// var web3 = Web3(rpcURL: "https://mainnet.infura.io/v3/c2b9ecfefe934b1ba89dc49532f44bf5")

struct Downloader {
  let collection : IpfsDownloader
  let firstIndex : Int
  let lastIndex : Int
}

let downloaders = [
  /*
   Downloader(
   collection:IpfsDownloader(
   name:"0N1 Force",baseUri:"ipfs://QmXgSuLPGuxxRuAana7JdoWmaS25oAcXv3x2pYMN9kVfg3"),
   firstIndex:1,
   lastIndex:7777
   ),
   Downloader(
   collection:IpfsDownloader(
   name:"DJENERATES",baseUri:"https://ipfs.io/ipfs/QmRPGJWkqdF9hhqrNjwGW7tuFHduSrtoeDA2PtnU65HYjX"),
   firstIndex:1,
   lastIndex:7699
   ),
   Downloader(
   collection:IpfsDownloader(
   name:"Craniums",baseUri:"https://raw.githubusercontent.com/recklesslabs/wickedcraniums/main"),
   firstIndex:0,
   lastIndex:10761
   ),
   
   Downloader(
   collection:IpfsDownloader(
   name:"DJENERATES",baseUri:"https://ipfs.io/ipfs/QmRPGJWkqdF9hhqrNjwGW7tuFHduSrtoeDA2PtnU65HYjX"),
   firstIndex:1,
   lastIndex:10000
   ),
   Downloader(
   collection:IpfsDownloader(
   name:"MutantApes",baseUri:"https://boredapeyachtclub.com/api/mutants"),
   firstIndex:0,
   lastIndex:10000
   )
   
   Downloader(
   collection:IpfsDownloader(
   name:"MutantApes",baseUri:"https://boredapeyachtclub.com/api/mutants"),
   firstIndex:0,
   lastIndex:10000
   ),
   */
  Downloader(
    collection:IpfsDownloader(
      name:"0xApes",baseUri:"ipfs://QmPyYXzqU7tsTxQ7WFN32iUKRy78T6ZiFGxYiJiv1TcoKE/"), // TODO
    firstIndex:10038,
    lastIndex:20145
  )
]


// var web3 = Web3(rpcURL: "https://mainnet.infura.io/v3/b4287cfd0a6b4849bd0ca79e144d3921")

print(try? hang(
  AlchemyApi.GetNFTs.get(
    owner: EthereumAddress(
      hex: "0xAe71923d145ec0eAEDb2CF8197A08f12525Bddf4",
      eip55: true),
    pageKey: nil)
)
)

// print(ENSContract.namehash("chilluminati.eth"))

// https://etherscan.io/address/0x00000000000c2e074ec69a0dfb2997ba6c7d2e1e#readContract
// -> resolver for namehash
// resolver : https://etherscan.io/address/0x4976fb03C32e5B8cfe2b6cCB31c09Ba78EBaBa41#readProxyContract
// -> add for namehash

// print(ENSContract.namehash("Ae71923d145ec0eAEDb2CF8197A08f12525Bddf4.addr.reverse".lowercased()))
// https://etherscan.io/address/0x00000000000c2e074ec69a0dfb2997ba6c7d2e1e#readContract
// -> resolver for namehash (lowercased address +++)
// resolver : https://etherscan.io/address/0x4976fb03C32e5B8cfe2b6cCB31c09Ba78EBaBa41#readProxyContract
// -> add for namehash



//
// THIS IS DEPRECATED, Use ipget to download directly

// DOwnload using cli: ./ipget --progress QmPyYXzqU7tsTxQ7WFN32iUKRy78T6ZiFGxYiJiv1TcoKE
/*
 try? downloaders.forEach { downloader in
 
 let firstIndex = downloader.firstIndex
 let lastIndex = downloader.lastIndex
 
 let collectionName = downloader.collection.name
 
 let minFileSize = 1000
 let parallelCount = 2//downloader.collection.baseUri.contains("ipfs://") ? 5 : 1
 
 print("Started downloading collection:\(collectionName)")
 
 func saveToken(_ tokenId : Int) -> Promise<Void> {
 return after(seconds:0.001)
 .then { _ in
 downloader.collection.tokenData(BigUInt(tokenId))
 .map { data -> Void in
 print("Downloaded \(tokenId)")
 // let filename = getImageFileName(collectionName,UInt(tokenId))
 // try! data.image.write(to: filename)
 saveJSON(getAttributesFileName(collectionName,UInt(tokenId)),data.attributes)
 }
 }
 }
 
 var tokenId = firstIndex
 var prev : [Promise<Int>] = Array(repeating:Promise.value(tokenId), count: parallelCount)
 
 for index in 0...(parallelCount-1) {
 prev[index] = Promise.value(firstIndex + index)
 }
 
 let fileManager = FileManager.default
 
 do {
 try fileManager.createDirectory(at: getImageDirectory(collectionName), withIntermediateDirectories: true, attributes: nil)
 try fileManager.createDirectory(at: getAttributesDirectory(collectionName), withIntermediateDirectories: true, attributes: nil)
 } catch {
 print(error)
 }
 
 while tokenId <= lastIndex {
 
 for index in 0...(parallelCount-1) {
 
 if (index > lastIndex) { continue }
 
 let next = prev[index].then { tokenId -> Promise<Int> in
 // print(tokenId,count)
 let fileName = getImageFileName(collectionName,UInt(tokenId)).path
 let attrFileName = getAttributesFileName(collectionName,UInt(tokenId)).path
 let p =
 // fileManager.fileExists(atPath:fileName)
 // && (minFileSize < (try! fileManager.attributesOfItem(atPath:fileName))[FileAttributeKey.size] as! UInt64)
 fileManager.fileExists(atPath:attrFileName)
 ? Promise.value(tokenId+parallelCount)
 : saveToken(tokenId).map { tokenId + parallelCount }
 return p.map { index in
 print("Done \(index)")
 return index
 }
 }
 prev[index] = next
 }
 tokenId+=parallelCount
 }
 
 try hang(when(fulfilled:prev))
 print("Done downloading. Verifing now")
 
 var indexMissing = false
 
 for index in firstIndex...lastIndex {
 let path = getImageFileName(collectionName,UInt(index)).path
 indexMissing = indexMissing || !fileManager.fileExists(atPath:path)
 
 let attr = try fileManager.attributesOfItem(atPath: path)
 if (minFileSize > attr[FileAttributeKey.size] as! UInt64) {
 print("Token=\(index) is empty")
 try fileManager.removeItem(atPath: path)
 }
 
 }
 print("All downloaded=\(downloader.collection.name)")
 }
 */
