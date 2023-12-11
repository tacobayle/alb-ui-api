const formEl = document.querySelector('.form');
formEl.addEventListener('submit', event => {
event.preventDefault();
const formData = new FormData(formEl);
const data = Object.fromEntries(formData);
const json = JSON.stringify(data);
fetch('http://10.41.135.46:5000/show-vs-sharing-same-cert', {
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
        <td>${values.tenant_ref}</td>
        <td>${values.name}</td>
        <td>${values.url}</td>
      </tr>`
    });
    document.getElementById("table_body").innerHTML=tableData;
  });
});
