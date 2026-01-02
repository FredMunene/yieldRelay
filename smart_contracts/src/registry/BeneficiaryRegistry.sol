// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

/// @title BeneficiaryRegistry
/// @notice Compliance registry for yield beneficiaries.
contract BeneficiaryRegistry is AccessControl {
    bytes32 public constant ATTESTOR_ROLE = keccak256("ATTESTOR_ROLE");

    struct Beneficiary {
        bool active;
        string metadata;
    }

    mapping(address => Beneficiary) private beneficiaries;

    event BeneficiaryAdded(address indexed beneficiary, string metadata);
    event BeneficiaryDisabled(address indexed beneficiary);
    event BeneficiaryMetadataUpdated(address indexed beneficiary, string metadata);

    error InvalidAddress();
    error NotEligible();

    constructor(address admin) {
        if (admin == address(0)) revert InvalidAddress();
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(ATTESTOR_ROLE, admin);
    }

    function addBeneficiary(address beneficiary, string calldata metadata)
        external
        onlyRole(ATTESTOR_ROLE)
    {
        if (beneficiary == address(0)) revert InvalidAddress();
        beneficiaries[beneficiary] = Beneficiary({active: true, metadata: metadata});
        emit BeneficiaryAdded(beneficiary, metadata);
    }

    function disableBeneficiary(address beneficiary) external onlyRole(ATTESTOR_ROLE) {
        if (!beneficiaries[beneficiary].active) revert NotEligible();
        beneficiaries[beneficiary].active = false;
        emit BeneficiaryDisabled(beneficiary);
    }

    function updateMetadata(address beneficiary, string calldata metadata)
        external
        onlyRole(ATTESTOR_ROLE)
    {
        if (!beneficiaries[beneficiary].active) revert NotEligible();
        beneficiaries[beneficiary].metadata = metadata;
        emit BeneficiaryMetadataUpdated(beneficiary, metadata);
    }

    function isEligible(address beneficiary) external view returns (bool) {
        return beneficiaries[beneficiary].active;
    }

    function getBeneficiary(address beneficiary) external view returns (Beneficiary memory) {
        return beneficiaries[beneficiary];
    }
}
