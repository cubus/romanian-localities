# Romanian::Localities

Available methods for Locality: 
  * name
  * parent_locality
  * county. 

Available methods for County: 
  * name
  * prefix
  * localities. 

## Installation

Install the gem and add to the application's Gemfile by executing:

    $ bundle add romanian-localities

If bundler is not being used to manage dependencies, install the gem by executing:

    $ gem install romanian-localities

## Usage

After installation following examples should be available:
```ruby
> tohanu_nou = Romanian::Localities::Locality.get name: "TOhanu nOU"
=> # Should return a Romanian::Localities::Locality instance

> tohanu_nou.name
=> "Tohanu Nou"

tohanu_nou.parent_locality
=> "Zarnesti"

tohanu_nou.county.name
=> "Braşov"

tohanu_nou.county.prefix
=> "BV"

tohanu_nou.county.localities
=> # Should return an array with Romanian::Localities::Locality objects (all localities belonging to this county)
  
# You can search by both parameters like this:  
> Romanian::Localities::Locality.get name: "TOhanu nOU", parent_locality: "Zărnesti"
=> # Should return a Romanian::Localities::Locality object

> brasov = Romanian::Localities::County.get name: "Brasov"
=> # Should return a Romanian::Localities::County object
  
> brasov.name  
=> "Braşov"

> brasov.prefix
=> "BV"

> brasov.localities
=> # Should return an array with Romanian::Localities::Locality objects, all localities (all localities belonging to this county)
  
> Romanian::Localities::Locality.get name: "TOhănu nOU", county: brasov
=> # Should return a Romanian::Localities::Locality object

> Romanian::Localities::County.get prefix: "BV"
=> # Should return a Romanian::Localities::County object
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/romanian-localities. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/[USERNAME]/romanian-localities/blob/master/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Romanian::Localities project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/[USERNAME]/romanian-localities/blob/master/CODE_OF_CONDUCT.md).
