// Setup the socket
if (socketName) {
	var proto = "";
	if (location.protocol === "http:") {
		proto = "ws://";
	} else {
		proto = "wss://";
	}
	var socket = new WebSocket(proto + location.host + "/api/v1/chat/" + socketName);
	console.log("Socket was created")
	
	socket.onopen = function (event) {
		// Restore an unfinished message from the last session
		const lostMessage = localStorage.getItem("lastmessage");
		if (lostMessage) {
			let field = document.getElementById("newMessageField");
			field.value = lostMessage;

			localStorage.removeItem("lastmessage");
		}
		
		let newMessageField = document.getElementById("newMessageField");
		let sendMessageButton = document.getElementById("sendMessageButton");
		newMessageField.disabled = false;
		sendMessageButton.disabled = false;
		
		console.log("Socket is open")
		query(socket)
	};
	
	socket.onclose = function (event) {
		saveCurrentMessage()
		
		//Disable the new message field
		let newMessageField = document.getElementById("newMessageField");
		let sendMessageButton = document.getElementById("sendMessageButton");
		newMessageField.disabled = true;
		sendMessageButton.disabled = true;
		
		let h1 = document.createElement('h1');
		let text = document.createTextNode("The connection was closed at: " + new Date(time).toLocaleString());
		h1.appendChild(text);
		chatarea.prepend(h1);
		console.log("Socket closed")
	};
} else {
	Error("Socket not set")
}

function saveCurrentMessage() {
	let val = document.getElementById("newMessageField").value ;
	
	if (val && val !== "") {
		localStorage.setItem("lastmessage", val);
	}
}

// Handle incomming messages
socket.addEventListener("message", event => {
	if (event.data instanceof Blob) {
		reader = new FileReader();

		reader.onload = () => {
			const msg = JSON.parse(reader.result);
			
			if (msg.newMessages) {
				const messages = msg.newMessages._0;
				
				console.log("New messages")				
				messages.sort((a, b) => a.timestamp > b.timestamp ? 1 : -1);
				
				messages.forEach((element) => {
					showMessage(element);
				});
				
			} else if (msg.requestReload){
				if (confirm('A vote opened\nThe server wants you to reload')) {
					socket.close()
					
					location.reload();
				}
			} else if (msg.error) {
				const error = msg.error._0;
				let errorField = document.getElementById("chaterror");
				
				if (error == "ratelimited") {
					const rateLimitedMessage = localStorage.getItem("lastsend");
					if (rateLimitedMessage) {
						let field = document.getElementById("newMessageField");
						field.value = rateLimitedMessage;

						localStorage.removeItem("lastsend");
					}
					errorField.innerText = "You are sending too many messages, please wait a while and try again";
				} else {
					errorField.innerText = error;

				}
				
			}
		};
		reader.readAsText(event.data);
	} else {
		console.log("Non blob result: " + event.data);
	}
	
});



// Request the latest messages
function query(socket) {
	var msg = {
		query: {}
	};
	socket.send(JSON.stringify(msg));
}

// Register hitting return in the text field
function keyPress(key){
	if(event.key === 'Enter') {
		sendMessage(socket)
	}
}

// Send a chat message
function sendMessage(socket) {
	let message = document.getElementById("newMessageField").value;
	if (message === "") {
		return
	}
	localStorage.setItem("lastsend", message);


	var msg = {
	send: {
		_0: message
		}
	};
	
	socket.send(JSON.stringify(msg));
	
	document.getElementById("newMessageField").value = "";
	
	let errorField = document.getElementById("chaterror");
	errorField.innerHTML = "";
}

// Add a new message to the UI
function showMessage(message) {
	// Defines header
	var b = document.createElement('b');
	var header = document.createElement('p');
	header.style = "display: flex; justify-content: space-between;";
	
	var span1 = document.createElement('span');
	var span2 = document.createElement('span');
	
	// Converts the timestamp from Swift's reference date which is January 1st 2001
	const time = (message.timestamp + 978307200) * 1000;
	const dateTimeStr = new Date(time).toLocaleString()

	
	span1.appendChild(document.createTextNode(message.sender));
	span2.appendChild(document.createTextNode(dateTimeStr));
	
	header.appendChild(span1);
	header.appendChild(span2);
	
	b.appendChild(header);
	
	// Inner block for the message
	var div = document.createElement('div');
	div.style = "display:inline-block;margin: 1em; vertical-align:top;";
	// Sets the text content of the message and replaces all urls with an a-tag
	let newMessage = urlify(message.message);
	div.innerHTML = newMessage;
	
	
	
	
	var img = document.createElement('img');
	img.width = "80";
	img.height = "80";
	img.style = "margin: 0.1em; border-radius: 50%; vertical-align:top;"
	if (message.imageURL) {
		img.src = message.imageURL;
	}
	
	// Outer div for the whole view
	var odiv = document.createElement('div');
	if (message.isSystemsMessage) {
		odiv.style = "padding: 1em 0.5em;margin:0.1em;background-color: coral;border-radius: 1em;";
	} else {
		odiv.style = "padding: 1em 0.5em;margin:0.1em;";
	}
	
	
	
	odiv.appendChild(b)
	odiv.appendChild(img);
	odiv.appendChild(div);

	let list = document.getElementById("chatlist");
	
	list.prepend(odiv);
}


// urlify from https://thewebdev.info/2021/04/17/how-to-detect-urls-in-a-javascript-string-and-convert-them-to-links/
// Replaces urls in strings with an a-tag
const urlify = (text) => {
	if (text){
		const urlRegex = /(\b(https?|ftp|file):\/\/[-A-Z0-9+&@#\/%?=~_|!:,.;]*[-A-Z0-9+&@#\/%=~_|])/ig;
		return text.replace(urlRegex, (url) => {
			return `<a href="${url}" target="_blank">${url}</a>`;
		})
	}
}
