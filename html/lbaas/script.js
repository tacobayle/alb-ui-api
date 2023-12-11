const formEl = document.querySelector('.form');
formEl.addEventListener('submit', event => {
    event.preventDefault();
    const formData = new FormData(formEl);
    const data = Object.fromEntries(formData);
    const json = JSON.stringify(data);
    console.log(json)


fetch('http://10.41.135.46:5000/lbaas', {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json'
  },
  body: json
}).then(res => {
    return res.json();
  })
  .then ((data) => {
    console.log(data);
    let tableData="";
    data.map((values) => {
      tableData+=`<tr>
        <td>${values.date}</td>
        <td>${values.controller_ip}</td>
        <td>${values.object_type}</td>
        <td><a href="${values.url}" target="_blank">${values.url}</a></td>
        <td>${values.status}</td>
      </tr>`
    });
    document.getElementById("table_body").innerHTML=tableData;
  });


});