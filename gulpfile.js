const fs = require('fs');
const path = require('path');
const gulp = require('gulp');
const osm = require('./results/osmjs/osm');

gulp.task('credits', function() {
  fs.readFile(path.resolve(__dirname, 'results/kalimantan.json'), function(err, data) {
    osm
      .parse(data.toString())
      .then(osm.getNames)
      .then(function(names) {
        fs.writeFile('results/kalimantan-credits.json', JSON.stringify(names, null, ' '), function(err) {});
      });
  });
});

gulp.task('pages', function() {
  gulp
    .src([
      'results/kalimantan-credits.json',
      'results/kalimantan.geojson'
    ])
    .pipe(gulp.dest('public/data'));
  gulp
    .src('resources/index.html')
    .pipe(gulp.dest('public'));
  gulp
    .src('resources/assets/app.css')
    .pipe(gulp.dest('public/assets'));
  gulp
    .src('resources/assets/app.js')
    .pipe(gulp.dest('public/assets'));
});
