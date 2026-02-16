<?php

require __DIR__ . '/../vendor/autoload.php';

use Slim\Factory\AppFactory;
use Elastic\Elasticsearch\ClientBuilder;

$app = AppFactory::create();
$app->addErrorMiddleware(true, true, true);

$esHost = getenv('ELASTICSEARCH_URL') ?: 'http://localhost:9200';
$client = ClientBuilder::create()->setHosts([$esHost])->build();

$app->get('/health', function ($request, $response) {
    $response->getBody()->write(json_encode([
        'status' => 'ok',
        'service' => 'search'
    ]));
    return $response->withHeader('Content-Type', 'application/json');
});

$app->get('/search', function ($request, $response) use ($client) {
    $params = $request->getQueryParams();
    $query = $params['q'] ?? '';

    if (empty($query)) {
        $response->getBody()->write(json_encode(['error' => 'query parameter q is required']));
        return $response->withStatus(400)->withHeader('Content-Type', 'application/json');
    }

    try {
        $result = $client->search([
            'index' => 'products',
            'body' => [
                'query' => [
                    'multi_match' => [
                        'query' => $query,
                        'fields' => ['name^2', 'description', 'category']
                    ]
                ]
            ]
        ]);

        $hits = array_map(function ($hit) {
            return [
                'id' => $hit['_id'],
                'score' => $hit['_score'],
                'product' => $hit['_source']
            ];
        }, $result['hits']['hits']);

        $response->getBody()->write(json_encode([
            'total' => $result['hits']['total']['value'],
            'results' => $hits
        ]));
    } catch (\Exception $e) {
        $response->getBody()->write(json_encode(['error' => $e->getMessage()]));
        return $response->withStatus(500)->withHeader('Content-Type', 'application/json');
    }

    return $response->withHeader('Content-Type', 'application/json');
});

$app->post('/index', function ($request, $response) use ($client) {
    $body = json_decode($request->getBody()->getContents(), true);

    try {
        $result = $client->index([
            'index' => 'products',
            'body' => $body
        ]);
        $response->getBody()->write(json_encode(['indexed' => $result['_id']]));
        return $response->withStatus(201)->withHeader('Content-Type', 'application/json');
    } catch (\Exception $e) {
        $response->getBody()->write(json_encode(['error' => $e->getMessage()]));
        return $response->withStatus(500)->withHeader('Content-Type', 'application/json');
    }
});

$port = getenv('PORT') ?: 3006;
$app->run();
