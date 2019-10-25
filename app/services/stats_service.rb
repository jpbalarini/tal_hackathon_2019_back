class StatsService
  INDEX = 'market-data'

  class << self
    def get(year: nil, make: nil, model: nil, top_left: nil, bottom_right: nil,
      max_turn_over: 100, days_ago: 30, precision: 3, routing: nil, size: 0, show_stats: false)
      precision = 12 if precision.to_i > 12
      precision = 1 if precision.to_i < 1
      if show_stats
        q = query_stats(year, make, model, max_turn_over, days_ago, precision, top_left, bottom_right, routing, size)
      else
        q = query(year, make, model, max_turn_over, days_ago, precision, top_left, bottom_right, routing, size)
      end
      res = ElasticsearchService.client.search(index: INDEX, body: q, request_cache: true)
      puts res
      return res
      # aggs = res['aggregations']
      # buckets = aggs['grid']['buckets']
      # aggregate(buckets)
    end

    private

    def aggregate(buckets)
      max_count = 0
      max_avg = 0
      buckets.each do |bucket|
        max_count = bucket['stats']['count'] if bucket['stats']['count'] > max_count
        max_avg = bucket['stats']['avg'] if bucket['stats']['avg'] > max_avg
      end
      points = []
      buckets.each do |bucket|
        location = bucket['centroid']['location']
        stats = bucket['stats']
        points << {
          "avg": stats["avg"],
          "std": stats["std_deviation"],
          "count": stats["count"],
          "center": location,
          "relative_count": Float(stats["count"]) / Float(max_count),
          "relative_avg": Float(stats["avg"]) / Float(max_avg)
        }
      end
      points
    end

    def query(year, make, model, max_turn_over, days_ago, precision, top_left, bottom_right, routing, size)
      query = {
        "size": size,
        "sort": [
          { "stats.last_seen": {"order": "desc"} },
          "_score"
        ],
        "query": {
          "bool": {
            "must": [
              {
                "has_parent": {
                  "parent_type": "dealer",
                  "query": {
                    "match_all": {}
                  },
                  "inner_hits": {}
                }
              },
              {
                "range": {
                  "stats.last_seen": {
                    "gte": "now-#{days_ago}d/d",
                    "lt": "now/d"
                  }
                }
              },
              {
                "range": {
                  "stats.total_days": {
                    "gt": "1"
                  }
                }
              }
            ]
          }
        },
        "aggs": query_aggregations(precision)
      }
      query_routing(query, routing)
      query_complete_data(query)
      query_filter_bounding_box(query, top_left, bottom_right)
      query_year(query, year)
      query_model(query, model)
      query_make(query, make)
      # query_max_turn_over(query, max_turn_over)
      query
    end

    def query_stats(year, make, model, max_turn_over, days_ago, precision, top_left, bottom_right, routing, size)
      query = {
        "query": {
          "has_child": {
            "type": "vehicle",
            "query": {
              "bool": {
                "must": [
                  {
                    "range": {
                      "stats.last_seen": {
                        "gte": "now-#{days_ago}d/d",
                        "lt": "now/d"
                      }
                    }
                  },
                  {
                    "range": {
                      "stats.total_days": {
                        "gt": "1"
                      }
                    }
                  }
                ]
              }
            },
            "score_mode": "sum",
            "inner_hits": {}
          }
        }
      }
      query_complete_data(query[:query][:has_child])
      query_filter_bounding_box(query[:query][:has_child], top_left, bottom_right)
      query_year(query[:query][:has_child], year)
      query_model(query[:query][:has_child], model)
      query_make(query[:query][:has_child], make)
      query
    end

    def query_routing(query, routing)
      if routing.present?
        query[:query][:bool][:must] << {
          "match": {
            "_routing": routing
          }
        }
      end
    end

    def query_complete_data(query)
      query[:query][:bool][:must] << {
        "exists": {
          "field": "vehicle.make"
        }
      }
      query[:query][:bool][:must] << {
        "exists": {
          "field": "vehicle.model"
        }
      }
      query[:query][:bool][:must] << {
        "exists": {
          "field": "vehicle.year"
        }
      }
      query[:query][:bool][:must] << {
        "exists": {
          "field": "stats.last_seen"
        }
      }
    end

    def query_aggregations(precision)
      {}
      # {
      #   "grid": {
      #     "geohash_grid": {
      #       "field": "stats.location",
      #       "precision": precision
      #     },
      #     "aggs": {
      #       "centroid": {
      #         "geo_centroid": {"field": "stats.location"}
      #       },
      #       "stats": {
      #         "extended_stats": {
      #           "field": "stats.total_days",
      #           "sigma": 3
      #         }
      #       }
      #     }
      #   }
      # }
    end

    def query_year(query, year)
      if year.present?
        if year.include?('-')
          year = year.split('-')
          query[:query][:bool][:must] << {
            "range": {
              "vehicle.year": {
                "gte": year[0],
                "lte": year[1]
              }
            }
          }
        else
          query[:query][:bool][:must] << {
            "match": {
              "vehicle.year": year
            }
          }
        end
      end
    end

    def query_model(query, model)
      if model.present?
        query[:query][:bool][:must] << {
          "match": {
            "vehicle.model": model
          }
        }
      end
    end

    def query_make(query, make)
      if make.present?
        query[:query][:bool][:must] << {
          "match": {
            "vehicle.make": make
          }
        }
      end
    end

    def query_filter_bounding_box(query, top_left, bottom_right)
      if top_left.present? && bottom_right.present?
        query[:query][:bool][:filter] = {
          "geo_bounding_box": {
            "stats.location": {
              "top_left": top_left,
              "bottom_right": bottom_right
            }
          }
        }
      end
    end

    def query_max_turn_over(query, max_turn_over)
      if max_turn_over.present?
        query[:query][:bool][:must] << {
          "range": {
            "stats.total_days": {
              "lte": max_turn_over
            }
          }
        }
      end
    end
  end
end
