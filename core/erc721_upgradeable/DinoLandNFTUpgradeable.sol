// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./DinosAccessControl.sol";

contract DinolandNFTUpgradeable is ERC721Upgradeable, DinosAccessControl {
    /*** EVENTS ***/

    /// @dev The DinoSpawned event is fired whenever a new dino comes into existence.
    event DinoSpawned(
        uint256 indexed _dinoId,
        address indexed _owner,
        uint256 _genes,
        uint128 _gender,
        uint128 _generation
    );
    /// @dev The DinoRetired event is fired whenever a new dino retired.
    event DinoRetired(uint256 indexed _dinoId);
    /// @dev The DinoEvolved event is fired whenever a new dino elvolved.
    event DinoEvolved(
        uint256 indexed _dinoId,
        uint256 _oldGenes,
        uint256 _newGenes
    );
    /// @dev The DinoTransfered event is fired whenever a dino has been transfered.
    event DinoTransfered(
        uint256 indexed _dinoId,
        address _oldOwner,
        address _newOwner
    );
    /// @dev The DinoUpdated event is fired whenever a dino has been updated.
    event DinoUpdated(uint256 indexed _dinoId);

    /*** DATA TYPES ***/

    /// @dev The main Dino struct, it includes all of the information about dino
    struct Dino {
        // The Dino's genetic code, a Dino genes never change except when they evolved
        uint256 genes;
        // The timestamp from the block when this dino came into existence.
        uint256 bornAt;
        // The timestamp from the block when this dino become adult.
        uint256 coolDownEndAt;
        // Dino's Gender, 1 stand for Male and 2 for Female
        uint128 gender;
        // The "generation number" of this dino.
        uint128 generation;
    }

    /*** STORAGES ***/

    using Strings for uint256;
    /// @dev A mapping from the owner to their dinos.
    mapping(address => uint256[]) userOwnedDinos;
    /// @dev An array containing the Dino struct for all Dinos in existence. The ID
    ///  of each dino is actually an index into this array.
    Dino[] dinos;
    /// @dev URI of the server contains dino's information.
    string dnlStorageURI;
    // @dev Dino's information data type, default is json
    string dnlStorageExtenstion = "json";

    /*** METHODS ***/

    /// @dev Init contract with some specific information and some genesis dinos.
    function initialize() public initializer {
        __ERC721_init("Dinoland NFT", "DINO");
        ceoAddress = msg.sender;
        spawningManager = msg.sender;
        dnlStorageExtenstion = "json";
        /// @dev Create some genesis dinos
        _createDino(1111, msg.sender, block.timestamp, 1, 0); // Normal Novis
        _createDino(1212, msg.sender, block.timestamp, 2, 0); // Rare Aquis
    }

    /// @dev An internal helper method to remove dino id from an array.
    function _removeDinoFromArray(uint256 _dinoId, uint256[] memory _array)
        internal
        pure
        returns (uint256[] memory)
    {
        for (uint256 i = 0; i < _array.length; i++) {
            if (_array[i] == _dinoId) {
                _array[i] = _array[_array.length - 1];
                break;
            }
        }
        delete (_array[_array.length - 1]);
        return _array;
    }

    /// @dev An external method to get dino information by Dino ID
    /// @param _dinoId The id of specific dino that you want to get information
    function getDino(uint256 _dinoId)
        external
        view
        returns (
            uint256 genes,
            uint256 bornAt,
            uint256 cooldownEndAt,
            uint128 gender,
            uint128 generation
        )
    {
        Dino memory dino = dinos[_dinoId];
        return (
            dino.genes,
            dino.bornAt,
            dino.coolDownEndAt,
            dino.gender,
            dino.generation
        );
    }

    /// @dev An external method to get dino ids list by owner Address
    /// @param _ownerAddress The owner address we want to get dino list
    function getDinosByOwner(address _ownerAddress)
        public
        view
        returns (uint256[] memory)
    {
        return userOwnedDinos[_ownerAddress];
    }

    function tokenURI(uint256 _dinoId)
        public
        view
        virtual
        override
        returns (string memory)
    {
        require(
            _exists(_dinoId),
            "ERC721Metadata: URI query for nonexistent token"
        );
        string memory baseURI = _baseURI();
        return
            bytes(baseURI).length > 0
                ? string(
                    abi.encodePacked(
                        _baseURI(),
                        "dino_",
                        _dinoId.toString(),
                        ".",
                        dnlStorageExtenstion
                    )
                )
                : "";
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return dnlStorageURI;
    }

    /// @dev An external method that allow CLevel to set storage dnlStorageURI value
    /// @param _dnlStorageURI Storage URI of Dinoland Project
    function setDNLStorageURI(string memory _dnlStorageURI)
        external
        onlyCLevel
    {
        dnlStorageURI = _dnlStorageURI;
    }

    /// @dev An external method that allow CLevel to set dnlStorageExtenstion value
    /// @param _dnlStorageExtension Storage Extension of Dinoland Project, default is json
    function setDNLStorageExtension(string memory _dnlStorageExtension)
        external
        onlyCLevel
    {
        dnlStorageExtenstion = _dnlStorageExtension;
    }

    /// @dev Assigns ownership of a specific Dino to from an address to another address.
    function transferFrom(
        address _from,
        address _to,
        uint256 _dinoId
    ) public virtual override {
        require(
            _isApprovedOrOwner(_msgSender(), _dinoId),
            "transfer caller is not owner nor approved"
        );
        _transfer(_from, _to, _dinoId);
        userOwnedDinos[_to].push(_dinoId);
        userOwnedDinos[_from] = _removeDinoFromArray(
            _dinoId,
            userOwnedDinos[_from]
        );
        emit DinoTransfered(_dinoId, _from, _to);
    }

    /// @dev Assigns ownership of a specific Dino to from an address to another address.
    function safeTransferFrom(
        address _from,
        address _to,
        uint256 _dinoId,
        bytes memory _data
    ) public virtual override {
        require(
            _isApprovedOrOwner(_msgSender(), _dinoId),
            "ERC721: transfer caller is not owner nor approved"
        );
        _safeTransfer(_from, _to, _dinoId, _data);
        userOwnedDinos[_to].push(_dinoId);
        userOwnedDinos[_from] = _removeDinoFromArray(
            _dinoId,
            userOwnedDinos[_from]
        );
        emit DinoTransfered(_dinoId, _from, _to);
    }

    /// @dev An external method that creates a new dino and stores it.
    /// Only be called by spawners
    /// @param _genes The dino's genes code.
    /// @param _owner The inital owner of this dino, must be non-zero.
    /// @param _gender The dino's gender 1 stand for Male and 2 for Female
    /// @param _generation The generation number of this dino, must be computed by caller.
    function createDino(
        uint256 _genes,
        address _owner,
        uint128 _gender,
        uint128 _generation
    ) external onlySpawner returns (uint256) {
        require(_genes >= 1111, "Dino genes is not valid");
        uint256 dinoId = _createDino(
            _genes,
            _owner,
            block.timestamp,
            _gender,
            _generation
        );
        emit DinoSpawned(dinoId, _owner, _genes, _gender, _generation);
        return dinoId;
    }

    function _createDino(
        uint256 _genes,
        address _owner,
        uint256 _coolDownEndAt,
        uint128 _gender,
        uint128 _generation
    ) private returns (uint256) {
        Dino memory dino = Dino(
            _genes,
            block.timestamp,
            _coolDownEndAt,
            _gender,
            _generation
        );
        dinos.push(dino);
        uint256 dinoId = dinos.length - 1;
        _mint(_owner, dinoId);
        userOwnedDinos[_owner].push(dinoId);
        return dinoId;
    }

    /// @dev An external method that allow spawner to retire a dino.
    /// Only be called by spawners
    /// @param _dinoId The dino's ID
    /// @param _rip Retire this dino or not
    function retireDino(uint256 _dinoId, bool _rip) external onlySpawner {
        if (_rip) {
            delete dinos[_dinoId];
            userOwnedDinos[ownerOf(_dinoId)] = _removeDinoFromArray(
                _dinoId,
                userOwnedDinos[ownerOf(_dinoId)]
            );
            _burn(_dinoId);
            emit DinoRetired(_dinoId);
        }
    }

    /// @dev An external method that allow spawner to evolve a dino and assign new genes to him.
    /// Only be called by spawners
    /// @param _dinoId The dino's ID
    /// @param _newGenes Dino's new genes
    function evolveDino(uint256 _dinoId, uint256 _newGenes)
        external
        onlySpawner
    {
        require(_newGenes >= 1111, "Dino genes is not valid");
        uint256 _oldGenes = dinos[_dinoId].genes;
        dinos[_dinoId].genes = _newGenes;
        emit DinoEvolved(_dinoId, _oldGenes, _newGenes);
    }

    /// @dev An external method that allow spawner to update a dino's information.
    /// Only be called by spawners
    /// @param _dinoId The dino's ID
    /// @param _newGenes Dino's new genes
    /// @param _newGender Dino's new gender
    /// @param _newGeneration Dino's new generation
    function updateDino(
        uint256 _dinoId,
        uint256 _newGenes,
        uint128 _newGender,
        uint128 _newGeneration
    ) external onlySpawner {
        require(_newGenes >= 1111, "Dino genes is not valid");
        require(_newGender == 1 || _newGender == 2, "Gender is not valid");
        require(_newGeneration >= 1, "Generation is not valid");
        dinos[_dinoId].genes = _newGenes;
        dinos[_dinoId].gender = _newGender;
        dinos[_dinoId].generation = _newGeneration;
        emit DinoUpdated(_dinoId);
    }

    /// @dev An external method that returns total Dino be stored in the contract.
    function totalSupply() public view returns (uint256) {
        return dinos.length;
    }
}
