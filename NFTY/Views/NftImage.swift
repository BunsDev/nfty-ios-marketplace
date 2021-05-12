//
//  NftImage.swift
//  NFTY
//
//  Created by Varun Kohli on 4/17/21.
//

import SwiftUI
import URLImage

struct NftImageImpl: View {
  
  @ObservedObject var url : ObservablePromise<URL>
  var samples : [String]
  var themeColor : Color
  var body: some View {
    
    ObservedPromiseView(
      data:url,
      progress:
        ZStack {
          Image(
            samples[
              Int.random(in: 0..<samples.count)
            ])
            .interpolation(.none)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .padding()
            .background(themeColor)
            .blur(radius:20)
          ProgressView()
            .progressViewStyle(CircularProgressViewStyle(tint: themeColor))
            .scaleEffect(2.0, anchor: .center)
        }) { url in
      URLImage(
        url:url,
        options: URLImageOptions(
          expireAfter: 60 * 60 * 24 * 10
        ),
        empty: {
          Image(
            samples[
              Int.random(in: 0..<samples.count)
            ])
            .interpolation(.none)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .padding()
            .background(themeColor)
            .blur(radius:20)
        },
        inProgress: { progress in
          ZStack {
            Image(
              samples[
                Int.random(in: 0..<samples.count)
              ])
              .interpolation(.none)
              .resizable()
              .aspectRatio(contentMode: .fit)
              .padding()
              .background(themeColor)
              .blur(radius:20)
            ProgressView(value:progress)
              .progressViewStyle(CircularProgressViewStyle(tint: themeColor))
              .scaleEffect(2.0, anchor: .center)
          }
        },
        failure: { error, retry in         // Display error and retry button
          VStack {
            Text(error.localizedDescription)
            Button("Retry", action: retry)
          }
        },
        content: { image in                // Content view
          image
            .interpolation(.none)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .padding()
            .background(themeColor)
        })
    }
  }
}

struct NftImage: View {
  var nft:NFT
  var samples:[String]
  var themeColor : Color
  
  enum Size {
    case small
    case medium
    case normal
    case large
  }
  
  var size : Size
  
  private func fontSize(_ size:Size) -> CGFloat {
    switch (size) {
    case .small:
      return 8
    case .medium:
      return 16
    case .normal:
      return 18
    case .large:
      return 23
    }
  }
  
  var body: some View {
    ZStack {
      switch(nft.media){
      case .image(let image):
        NftImageImpl(url:image.url,samples:samples,themeColor:themeColor)
      case .asciiPunk(let asciiPunk):
        AsciiPunkView(asciiPunk:asciiPunk.ascii,samples:samples,themeColor:themeColor,fontSize:fontSize(size))
      }
      //.padding()
      HStack {
        Spacer()
        switch(size) {
        case .normal:
          VStack {
            FavButton(nft:nft,size:.medium)
            Spacer()
          }
        case .large,.medium:
          VStack {
            Spacer()
            FavButton(nft:nft,size:.large)
          }
        case .small:
          VStack {
          }
        }
      }
    }.background(themeColor)
  }
}

struct NftImage_Previews: PreviewProvider {
  static var previews: some View {
    NftImage(nft:SampleToken,samples:SAMPLE_PUNKS,themeColor:SampleCollection.info.themeColor,size:.normal)
  }
}
