<?php

require '../vendor/autoload.php';

/**
 * Check to see if a container name is already taken
 *
 * @param $client
 * @param $vmName
 * @return bool
 */
function vmExists($client, $vmName )
{

    $vms = $client->get( '/PrismGateway/services/rest/v1/vms' )->json();

    if( $vms[ 'metadata' ][ 'grandTotalEntities' ] > 0 )
    {
        foreach( $vms[ 'entities' ] as $vm )
        {
            if( $vm[ 'vmName' ] == $vmName )
            {
                return true;
            }
        }
        return false;
    }
}

try
{

    $client = new \DigitalFormula\ApiRequest\ApiRequest(
        $_POST[ 'cluster-username' ],
        $_POST[ 'cluster-password' ],
        $_POST[ 'cvm-address' ],
        $_POST[ 'cluster-port' ],
        $_POST[ 'cluster-timeout' ]
    );

    $containers = $client->get( '/PrismGateway/services/rest/v1/containers' )->json();

    $containerId = '';
    if( $containers[ 'metadata' ][ 'grandTotalEntities' ] > 0 ) {

        /* A container has been found - we can carry on */
        $containerId = $containers[ 'entities' ][ 0 ][ 'id' ];

        if( !vmExists( $client, $_POST[ 'server-name' ] ) )
        {

            $parameters = [];

            switch( $_POST[ 'server-profile' ] )
            {
                case 'exch':

                    $parameters = [
                        "description" => "Microsoft Exchange 2013 Mailbox, created by Nutanix API Demo",
                        "numVcpus" => "2",
                        "name" => $_POST['server-name'],
                        "memoryMb" => "8192",
                        "vmDisks" => [
                            [
                                "isCdrom" => "false",
                                "vmDiskCreate" => [
                                    "size" => "128849018880",
                                    "containerId" => $containerId
                                ]
                            ],
                            [
                                "isCdrom" => "false",
                                "vmDiskCreate" => [
                                    "size" => "536870912000",
                                    "containerId" => $containerId
                                ]
                            ]
                        ]
                    ];

                    break;
                case 'dc':

                    $parameters = [
                        "description" => "Domain Controller, created by Nutanix API Demo",
                        "numVcpus" => "1",
                        "name" => $_POST['server-name'],
                        "memoryMb" => "2048",
                        "vmDisks" => [
                            [
                                "isCdrom" => "false",
                                "vmDiskCreate" => [
                                    "size" => "268435456000",
                                    "containerId" => $containerId
                                ]
                            ]
                        ]
                    ];

                    break;
                case 'lamp':

                    $parameters = [
                        "description" => "Web Server (LAMP), created by Nutanix API Demo",
                        "numVcpus" => "1",
                        "name" => $_POST['server-name'],
                        "memoryMb" => "4096",
                        "vmDisks" => [
                            [
                                "isCdrom" => "false",
                                "vmDiskCreate" => [
                                    "size" => "42949672960",
                                    "containerId" => $containerId
                                ]
                            ]
                        ]
                    ];

                    break;
            }

            $response = $client->post( '/api/nutanix/v0.8/vms/', $parameters );

            /* return a successful result */
            echo(json_encode(array(
                'result' => 'ok',
            )));

        }
        else
        {
            echo( json_encode( array(
                'result' => 'failed',
                'message' => 'That VM name is already in use. Please specify a different VM name, then try again.'
            )));
        }

    }
    else
    {
        echo( json_encode( array(
            'result' => 'failed',
            'message' => "No containers were found in this cluster.&nbsp;&nbsp;:(&nbsp;&nbsp;Please create at least one cluster, then try again."
        )));
    }

}
catch ( GuzzleHttp\Exception\RequestException $e )
{
    /* can't connect to CVM */
    echo( json_encode( array(
        'result' => 'failed',
        // 'message' => $e->getMessage()
        'message' => "An error occurred while creating the VM.&nbsp;&nbsp;Please confirm that you can connect to the CVM at address " . $_POST[ 'cvm-address-container' ] . ' and that you have permissions to make cluster changes, then try again.'
    )));
}
catch( Exception $e )
{
    /* something else happened that we weren't prepared for ... */
    echo( json_encode( array(
        'result' => 'failed',
        'message' => 'An unknown error has occurred.&nbsp;&nbsp;Sorry about that.&nbsp;&nbsp;Give it another go shortly.&nbsp;&nbsp;:)'
    )));
}