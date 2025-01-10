import {Stack, StackProps, Duration, RemovalPolicy} from 'aws-cdk-lib';
import {Construct} from 'constructs';
import {Bucket} from 'aws-cdk-lib/aws-s3';
import {
    Distribution,
    PriceClass,
    HttpVersion,
    OriginAccessIdentity,
    ResponseHeadersPolicy,
    HeadersFrameOption,
    SSLMethod,
    SecurityPolicyProtocol,
    AllowedMethods,
    CachedMethods,
    ViewerProtocolPolicy,
    CachePolicy,
    Function as CloudFrontFunction,
    FunctionCode,
    FunctionEventType,
} from 'aws-cdk-lib/aws-cloudfront';
import {
    Certificate,
    CertificateValidation,
} from 'aws-cdk-lib/aws-certificatemanager';
import {CfnWebACL} from 'aws-cdk-lib/aws-wafv2';
import {
    ARecord,
    RecordTarget,
    HostedZone,
    IHostedZone,
} from 'aws-cdk-lib/aws-route53';
import {CloudFrontTarget} from 'aws-cdk-lib/aws-route53-targets';
import * as assert from 'assert';
import {S3Origin} from 'aws-cdk-lib/aws-cloudfront-origins';
import {BucketDeployment, Source} from 'aws-cdk-lib/aws-s3-deployment';
import path = require('path');
import {Domain, DomainNameByEnv} from '.';

interface FrontendStackProps extends StackProps {
    company: string;
    project: string;
    environment: string;
    domain: Domain;
    domainNameByEnv: DomainNameByEnv;
    storageOrigin: S3Origin;
}

export class FrontendStack extends Stack {
    constructor(scope: Construct, id: string, props: FrontendStackProps) {
        super(scope, id, props);

        const {
            company,
            project,
            environment,
            domain,
            domainNameByEnv,
            storageOrigin,
        } = props;

        const domains = [
            {
                name: `*.${domainNameByEnv}`,
                zone: HostedZone.fromLookup(this, 'zone-root', {
                    domainName: domain,
                }),
            },
            ...(environment === 'main'
                ? [
                      {
                          name: 'az-eventtickets.com',
                          zone: HostedZone.fromLookup(
                              this,
                              'zone-additional-1',
                              {domainName: 'az-eventtickets.com'},
                          ),
                      },
                      {
                          name: 'www.az-eventtickets.com',
                          zone: HostedZone.fromLookup(
                              this,
                              'zone-additional-2',
                              {domainName: 'az-eventtickets.com'},
                          ),
                      },
                      {
                          name: 'werte-event-tickets.de',
                          zone: HostedZone.fromLookup(
                              this,
                              'zone-additional-3',
                              {domainName: 'werte-event-tickets.de'},
                          ),
                      },
                      {
                          name: 'www.werte-event-tickets.de',
                          zone: HostedZone.fromLookup(
                              this,
                              'zone-additional-4',
                              {domainName: 'werte-event-tickets.de'},
                          ),
                      },
                      {name: 'tickets.sponsorships.sap.com', zone: null},
                      {name: '*.go10.events.sap.com', zone: null},
                      {name: 'www.tickets.schwarz', zone: null},
                  ]
                : []),
        ];

        const bucket = new Bucket(this, 'frontend-bucket', {
            bucketName: `${company}.${project}.${environment}.frontend`,
            removalPolicy: RemovalPolicy.DESTROY,
            autoDeleteObjects: true,
        });

        const firstDomain = domains.at(0);
        assert(firstDomain, 'There must be at least one domain');

        const certificate = new Certificate(this, 'frontend-certificate', {
            domainName: firstDomain.name,
            subjectAlternativeNames: domains
                .slice(1)
                .map(domain => domain.name),
            validation: CertificateValidation.fromDnsMultiZone(
                domains.reduce<Record<string, IHostedZone>>((acc, domain) => {
                    if (domain.zone) {
                        acc[domain.name] = domain.zone;
                    }
                    return acc;
                }, {}),
            ),
        });

        let acl: CfnWebACL | undefined;

        if (environment === 'main') {
            acl = new CfnWebACL(this, 'cloudfront-acl', {
                defaultAction: {allow: {}},
                name: `${project}-${environment}-frontend`,
                scope: 'CLOUDFRONT',
                visibilityConfig: {
                    metricName: 'captcha_metric',
                    sampledRequestsEnabled: false,
                    cloudWatchMetricsEnabled: false,
                },
                rules: [
                    {
                        name: 'show-captcha',
                        action: {captcha: {}},
                        priority: 0,
                        visibilityConfig: {
                            metricName: 'captcha_metric',
                            sampledRequestsEnabled: true,
                            cloudWatchMetricsEnabled: true,
                        },
                        statement: {
                            andStatement: {
                                statements: [
                                    {
                                        orStatement: {
                                            statements: [
                                                {
                                                    byteMatchStatement: {
                                                        searchString: 'login',
                                                        fieldToMatch: {
                                                            uriPath: {},
                                                        },
                                                        textTransformations: [
                                                            {
                                                                priority: 0,
                                                                type: 'NONE',
                                                            },
                                                        ],
                                                        positionalConstraint:
                                                            'CONTAINS',
                                                    },
                                                },
                                                {
                                                    byteMatchStatement: {
                                                        searchString:
                                                            'registration/public',
                                                        fieldToMatch: {
                                                            uriPath: {},
                                                        },
                                                        textTransformations: [
                                                            {
                                                                priority: 0,
                                                                type: 'NONE',
                                                            },
                                                        ],
                                                        positionalConstraint:
                                                            'CONTAINS',
                                                    },
                                                },
                                                {
                                                    byteMatchStatement: {
                                                        searchString:
                                                            'registration/accept',
                                                        fieldToMatch: {
                                                            uriPath: {},
                                                        },
                                                        textTransformations: [
                                                            {
                                                                priority: 0,
                                                                type: 'NONE',
                                                            },
                                                        ],
                                                        positionalConstraint:
                                                            'CONTAINS',
                                                    },
                                                },
                                                {
                                                    byteMatchStatement: {
                                                        searchString:
                                                            'registration/decline',
                                                        fieldToMatch: {
                                                            uriPath: {},
                                                        },
                                                        textTransformations: [
                                                            {
                                                                priority: 0,
                                                                type: 'NONE',
                                                            },
                                                        ],
                                                        positionalConstraint:
                                                            'CONTAINS',
                                                    },
                                                },
                                                {
                                                    byteMatchStatement: {
                                                        searchString:
                                                            'reset-password',
                                                        fieldToMatch: {
                                                            uriPath: {},
                                                        },
                                                        textTransformations: [
                                                            {
                                                                priority: 0,
                                                                type: 'NONE',
                                                            },
                                                        ],
                                                        positionalConstraint:
                                                            'CONTAINS',
                                                    },
                                                },
                                            ],
                                        },
                                    },
                                    {
                                        notStatement: {
                                            statement: {
                                                byteMatchStatement: {
                                                    searchString:
                                                        'tickets.sponsorships.sap.com',
                                                    fieldToMatch: {
                                                        singleHeader: {
                                                            Name: 'host',
                                                        },
                                                    },
                                                    textTransformations: [
                                                        {
                                                            priority: 0,
                                                            type: 'NONE',
                                                        },
                                                    ],
                                                    positionalConstraint:
                                                        'CONTAINS',
                                                },
                                            },
                                        },
                                    },
                                    {
                                        notStatement: {
                                            statement: {
                                                byteMatchStatement: {
                                                    searchString:
                                                        'sap.tickgets.com',
                                                    fieldToMatch: {
                                                        singleHeader: {
                                                            Name: 'host',
                                                        },
                                                    },
                                                    textTransformations: [
                                                        {
                                                            priority: 0,
                                                            type: 'NONE',
                                                        },
                                                    ],
                                                    positionalConstraint:
                                                        'CONTAINS',
                                                },
                                            },
                                        },
                                    },
                                    {
                                        notStatement: {
                                            statement: {
                                                byteMatchStatement: {
                                                    searchString:
                                                        'pe-impact-summit.go10.events.sap.com',
                                                    fieldToMatch: {
                                                        singleHeader: {
                                                            Name: 'host',
                                                        },
                                                    },
                                                    textTransformations: [
                                                        {
                                                            priority: 0,
                                                            type: 'NONE',
                                                        },
                                                    ],
                                                    positionalConstraint:
                                                        'CONTAINS',
                                                },
                                            },
                                        },
                                    },
                                ],
                            },
                        },
                    },
                ],
            });
        }

        const oai = new S3Origin(bucket, {
            originAccessIdentity: new OriginAccessIdentity(
                this,
                'frontend-oai',
                {
                    comment: `${project}.${environment}.frontend`,
                },
            ),
        });

        const responseHeadersPolicy = new ResponseHeadersPolicy(
            this,
            'response-headers-policy',
            {
                responseHeadersPolicyName: `${project}-${environment}-frontend`,
                securityHeadersBehavior: {
                    strictTransportSecurity: {
                        accessControlMaxAge: Duration.seconds(31536000),
                        includeSubdomains: false,
                        preload: false,
                        override: false,
                    },
                    frameOptions: {
                        frameOption: HeadersFrameOption.SAMEORIGIN,
                        override: true,
                    },
                },
            },
        );

        // Create CloudFront Function for security.txt path rewriting
        const securityTxtFunction = new CloudFrontFunction(
            this,
            'security-txt-function',
            {
                code: FunctionCode.fromInline(`
                function handler(event) {
                    var request = event.request;
                    var host = request.headers.host.value;
                    
                    // Extract tenant name from the hostname (e.g., "tenant" from "tenant.tickgets.com")
                    var tenant = host.split('.')[0];
                    
                    // Rewrite the URI to point to the tenant-specific security.txt file
                    request.uri = '/' + tenant + '/public/.well-known/security.txt';
                    
                    return request;
                }
            `),
            },
        );

        const distribution = new Distribution(this, 'distribution', {
            priceClass: PriceClass.PRICE_CLASS_ALL,
            httpVersion: HttpVersion.HTTP2_AND_3,
            enabled: true,
            comment: `${project}.${environment}.frontend`,
            enableIpv6: false,
            webAclId: acl ? acl.attrArn : undefined,
            defaultRootObject: 'index.html',
            domainNames: domains.map(domain => domain.name),
            errorResponses: [
                {
                    httpStatus: 404,
                    responseHttpStatus: 200,
                    ttl: Duration.seconds(3600),
                    responsePagePath: '/index.html',
                },
                {
                    httpStatus: 403,
                    responseHttpStatus: 200,
                    ttl: Duration.seconds(3600),
                    responsePagePath: '/index.html',
                },
            ],
            defaultBehavior: {
                origin: oai,
                allowedMethods: AllowedMethods.ALLOW_GET_HEAD,
                cachedMethods: CachedMethods.CACHE_GET_HEAD,
                viewerProtocolPolicy: ViewerProtocolPolicy.REDIRECT_TO_HTTPS,
                responseHeadersPolicy: responseHeadersPolicy,
                cachePolicy: CachePolicy.CACHING_OPTIMIZED,
            },
            additionalBehaviors: {
                // Specific behavior for security.txt requests
                '/.well-known/security.txt': {
                    origin: oai,
                    allowedMethods: AllowedMethods.ALLOW_GET_HEAD,
                    cachedMethods: CachedMethods.CACHE_GET_HEAD,
                    viewerProtocolPolicy:
                        ViewerProtocolPolicy.REDIRECT_TO_HTTPS,
                    responseHeadersPolicy:
                        ResponseHeadersPolicy.CORS_ALLOW_ALL_ORIGINS,
                    cachePolicy: CachePolicy.CACHING_OPTIMIZED,
                    functionAssociations: [
                        {
                            function: securityTxtFunction,
                            eventType: FunctionEventType.VIEWER_REQUEST,
                        },
                    ],
                },
                // General behavior for other .well-known files
                '.well-known/*': {
                    origin: storageOrigin,
                    allowedMethods: AllowedMethods.ALLOW_GET_HEAD,
                    cachedMethods: CachedMethods.CACHE_GET_HEAD,
                    viewerProtocolPolicy:
                        ViewerProtocolPolicy.REDIRECT_TO_HTTPS,
                    responseHeadersPolicy:
                        ResponseHeadersPolicy.CORS_ALLOW_ALL_ORIGINS,
                    cachePolicy: CachePolicy.CACHING_OPTIMIZED,
                },
            },
            certificate: certificate,
            sslSupportMethod: SSLMethod.SNI,
            minimumProtocolVersion: SecurityPolicyProtocol.TLS_V1_2_2021,
        });

        distribution.applyRemovalPolicy(
            environment === 'main'
                ? RemovalPolicy.RETAIN
                : RemovalPolicy.DESTROY,
        );

        const cloudfrontRecordTarget = RecordTarget.fromAlias(
            new CloudFrontTarget(distribution),
        );

        domains.forEach(domain => {
            if (domain.zone) {
                new ARecord(this, `route53-record-${domain.name}-a`, {
                    zone: domain.zone,
                    recordName: domain.name,
                    deleteExisting: true,
                    target: cloudfrontRecordTarget,
                });
            }
        });

        new BucketDeployment(this, 'bucket-deployment', {
            sources: [
                Source.asset(
                    __dirname.replace(
                        /packages.*/,
                        path.join('packages', 'frontend', 'dist'),
                    ),
                ),
            ],
            destinationBucket: bucket,
            destinationKeyPrefix: '/',
            distribution: distribution,
            distributionPaths: ['/*'],
            memoryLimit: 1024,
        });
    }
}
