import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers'
import { expect } from 'chai'
import { Contract, ContractFactory } from 'ethers'
import { deployments, ethers } from 'hardhat'

import { Options } from '@layerzerolabs/lz-v2-utilities'

describe('ICARouter Test', function () {
    // Constant representing a mock Endpoint ID for testing purposes
    const eidA = 1
    const eidB = 2
    // Declaration of variables to be used in the test suite
    let ICARouter: ContractFactory
    let EndpointV2Mock: ContractFactory
    let ownerA: SignerWithAddress
    let ownerB: SignerWithAddress
    let endpointOwner: SignerWithAddress
    let icaRouterA: Contract
    let icaRouterB: Contract
    let mockEndpointV2A: Contract
    let mockEndpointV2B: Contract

    // Before hook for setup that runs once before all tests in the block
    before(async function () {
        // Contract factory for our tested contract
        ICARouter = await ethers.getContractFactory('ICARouter')

        // Fetching the first three signers (accounts) from Hardhat's local Ethereum network
        const signers = await ethers.getSigners()

        ownerA = signers.at(0)!
        ownerB = signers.at(1)!
        endpointOwner = signers.at(2)!

        // The EndpointV2Mock contract comes from @layerzerolabs/test-devtools-evm-hardhat package
        // and its artifacts are connected as external artifacts to this project
        //
        // Unfortunately, hardhat itself does not yet provide a way of connecting external artifacts,
        // so we rely on hardhat-deploy to create a ContractFactory for EndpointV2Mock
        //
        // See https://github.com/NomicFoundation/hardhat/issues/1040
        const EndpointV2MockArtifact = await deployments.getArtifact('EndpointV2Mock')
        EndpointV2Mock = new ContractFactory(EndpointV2MockArtifact.abi, EndpointV2MockArtifact.bytecode, endpointOwner)
    })

    // beforeEach hook for setup that runs before each test in the block
    beforeEach(async function () {
        // Deploying a mock LZ EndpointV2 with the given Endpoint ID
        mockEndpointV2A = await EndpointV2Mock.deploy(eidA)
        mockEndpointV2B = await EndpointV2Mock.deploy(eidB)

        // Deploying two instances of MyOApp contract and linking them to the mock LZEndpoint
        icaRouterA = await ICARouter.deploy(eidA, mockEndpointV2A.address, ownerA.address)
        icaRouterB = await ICARouter.deploy(eidB, mockEndpointV2B.address, ownerB.address)

        // Setting destination endpoints in the LZEndpoint mock for each MyOApp instance
        await mockEndpointV2A.setDestLzEndpoint(icaRouterB.address, mockEndpointV2B.address)
        await mockEndpointV2B.setDestLzEndpoint(icaRouterA.address, mockEndpointV2A.address)

        // Setting each MyOApp instance as a peer of the other
        await icaRouterA.connect(ownerA).setPeer(eidB, ethers.utils.zeroPad(icaRouterB.address, 32))
        await icaRouterB.connect(ownerB).setPeer(eidA, ethers.utils.zeroPad(icaRouterA.address, 32))
    })

    // A test case to verify message sending functionality
    it('should send a message to each destination OApp', async function () {
        // Assert initial state of data in both MyOApp instances
        // expect(await icaRouterA.data()).to.equal('Nothing received yet.')
        // expect(await icaRouterB.data()).to.equal('Nothing received yet.')
        // const options = Options.newOptions().addExecutorLzReceiveOption(200000, 0).toHex().toString()

        // // Define native fee and quote for the message send operation
        // let nativeFee = 0
        // ;[nativeFicaRouterAee] = await myOAppA.quote(eidB, 'Test message.', options, false)

        // // Execute send operation from myOAppA
        // await myOAppA.send(eidB, 'Test message.', options, { value: nativeFee.toString() })

        // // Assert the resulting state of data in both MyOApp instances
        // expect(await myOAppA.data()).to.equal('Nothing received yet.')
        // expect(await myOAppB.data()).to.equal('Test message.')
    })
})
