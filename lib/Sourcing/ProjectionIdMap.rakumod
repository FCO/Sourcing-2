unit role Sourcing::ProjectionIdMap;
use Sourcing::ProjectionId;

has Str %.projection-id-map{Str};

method projection-id-map { %!projection-id-map }
