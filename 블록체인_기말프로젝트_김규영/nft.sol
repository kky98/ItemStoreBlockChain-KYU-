// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract MintNftToken is ERC721Enumerable {
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIds;

    //constructor(string memory _name, string memory _symbol) ERC721(_name, _symbol) {}
    constructor() ERC721("iki", "jquery_symbol") {}

    //숫자가 들어가면 문자를 매핑 해줌
    mapping(uint256 => string) public tokenURIs;

    // 기존 ERC721에 있어서 오버라이드 한 것

    function tokenURI(uint256 _tokenId)
        public
        view
        override
        returns (string memory)
    {
        // 토큰 ID를 넣어주면 IPFS에서 전달받은 URL이 리턴 되게 만듬
        return tokenURIs[_tokenId];
    }

    //민팅할 때 IPFS에서 전달 받은 메타 JSON파일을 전달받고
    function mintNFT(string memory _tokenURI) public returns (uint256) {
        _tokenIds.increment();

        // 토큰 아이디가 순차적으로 증가를 하면서
        uint256 tokenId = _tokenIds.current();
        // 민팅을 할 때 받는 IPFS에 업로드한 메타 JSON파일의 토큰 URI를 넣으면 토큰의 고유한
        // 아이디 값을 전달받게 됨
        tokenURIs[tokenId] = _tokenURI;

        // 메타마스크 지갑에서 넘어오는 SENDER의 주소를 가져와서 민팅하게끔
        _mint(msg.sender, tokenId);

        return tokenId;
    }

    struct NftTokenData {
        uint256 nftTokenId;
        string nftTokenURI;
        uint256 price;
    }

    function getNftTokens(address _nftTokenOwner)
        public
        view
        returns (NftTokenData[] memory)
    {
        // 해당 주인이 몇개의 토큰을 가지고 있는지 알아내고
        uint256 balanceLength = balanceOf(_nftTokenOwner);
        //require(balanceLength != 0, "Owner did not have token.");

        NftTokenData[] memory nftTokenData = new NftTokenData[](balanceLength);
        // 그 함수만큼 반복문으로 돌리면 주인이 가지고 있는 토큰을 알 수 있게
        for (uint256 i = 0; i < balanceLength; i++) {
            uint256 nftTokenId = tokenOfOwnerByIndex(_nftTokenOwner, i);
            string memory nftTokenURI = tokenURI(nftTokenId);
            uint256 tokenPrice = getNftTokenPrice(nftTokenId);
            nftTokenData[i] = NftTokenData(nftTokenId, nftTokenURI, tokenPrice);
        }

        return nftTokenData;
    }

    //판매 등록
    mapping(uint256 => uint256) public nftTokenPrices;
    uint256[] public onSaleNftTokenArray;

    function setSaleNftToken(uint256 _tokenId, uint256 _price) public {
        address nftTokenOwner = ownerOf(_tokenId);

        require(nftTokenOwner == msg.sender, "Caller is not nft token owner.");
        require(_price > 0, "Price is zero or lower.");
        require(
            nftTokenPrices[_tokenId] == 0,
            "This nft token is already on sale."
        );
        require(
            isApprovedForAll(nftTokenOwner, address(this)),
            "nft token owner did not approve token."
        );

        nftTokenPrices[_tokenId] = _price;
        onSaleNftTokenArray.push(_tokenId); //판매중인 nft list
    }

    // 판매리스트
    function getSaleNftTokens() public view returns (NftTokenData[] memory) {
        uint256[] memory onSaleNftToken = getSaleNftToken();
        NftTokenData[] memory onSaleNftTokens = new NftTokenData[](
            onSaleNftToken.length
        );

        for (uint256 i = 0; i < onSaleNftToken.length; i++) {
            uint256 tokenId = onSaleNftToken[i];
            uint256 tokenPrice = getNftTokenPrice(tokenId);
            onSaleNftTokens[i] = NftTokenData(
                tokenId,
                tokenURI(tokenId),
                tokenPrice
            );
        }

        return onSaleNftTokens;
    }

    function getSaleNftToken() public view returns (uint256[] memory) {
        return onSaleNftTokenArray;
    }

    function getNftTokenPrice(uint256 _tokenId) public view returns (uint256) {
        return nftTokenPrices[_tokenId];
    }

    //구매함수
    function buyNftToken(uint256 _tokenId) public payable {
        uint256 price = nftTokenPrices[_tokenId];
        address nftTokenOwner = ownerOf(_tokenId);

        require(price > 0, "nft token not sale.");
        require(price <= msg.value, "caller sent lower than price.");
        require(nftTokenOwner != msg.sender, "caller is nft token owner.");
        require(
            isApprovedForAll(nftTokenOwner, address(this)),
            "nft token owner did not approve token."
        );

        payable(nftTokenOwner).transfer(msg.value);

        IERC721(address(this)).safeTransferFrom(
            nftTokenOwner,
            msg.sender,
            _tokenId
        );

        //판매 리스트에서 삭제
        removeToken(_tokenId);
    }

    function burn(uint256 _tokenId) public {
        address addr_owner = ownerOf(_tokenId);
        require(
            addr_owner == msg.sender,
            "msg.sender is not the owner of the token"
        );
        _burn(_tokenId);
        removeToken(_tokenId);
    }

    function removeToken(uint256 _tokenId) private {
        nftTokenPrices[_tokenId] = 0;

        for (uint256 i = 0; i < onSaleNftTokenArray.length; i++) {
            if (nftTokenPrices[onSaleNftTokenArray[i]] == 0) {
                onSaleNftTokenArray[i] = onSaleNftTokenArray[
                    onSaleNftTokenArray.length - 1
                ];
                onSaleNftTokenArray.pop();
            }
        }
    }
}
