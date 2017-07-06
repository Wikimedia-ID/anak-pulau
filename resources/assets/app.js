var mymap = L.map('mapid');

var osmUrl = 'http://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png';
var osmAttrib = 'Map data © <a href="http://openstreetmap.org">OpenStreetMap</a> contributors';

var osm = new L.TileLayer(osmUrl, {
  minZoom: 5,
  maxZoom: 15,
  attribution: osmAttrib
});

mymap.setView([-2, 120], 5);
mymap.addLayer(osm);

$(document).ready(function() {
  $.getJSON('data/kalimantan-credits.json', function(data) {
    users = [];

    Object.keys(data).map(function(key) {
      users.push({
        name: key,
        count: data[key]
      });
    });

    users.sort(function(a, b) {
      return b.count - a.count;
    });

    users.map(function(user) {
      $('#names').append('<h5><a target="_blank" href="http://www.openstreetmap.org/user/'+user.name+'/history">'+user.name+'</a> - '+user.count+' kontribusi</h5>');
    });
  });

  $.getJSON('data/kalimantan.geojson', function(data) {
    L.geoJSON(data).addTo(mymap);
  });
});
