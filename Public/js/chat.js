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
		let chatarea = document.getElementById("chatarea");
		chatarea.disabled = false
		
		console.log("Socket is open")
		query(socket)
	};
	
	socket.onclose = function (event) {
		saveCurrentMessage()
		chatarea.disabled = true;
		let field = document.getElementById("newMessageField");
		field.disabled = true;
		
		let h1 = document.createElement('h1');
		let text = document.createTextNode("The connection was closed");
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
				console.log(messages)
				
				messages.sort((a, b) => a.timestamp > b.timestamp ? 1 : -1);
				
				messages.forEach((element) => {
					showMessage(element);
				});
				
			} else if (msg.requestReload){
				if (confirm('The server wants you to reload')) {
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
					errorField.innerHTML = "You are sending too many messages, please wait a while and try again";
				} else {
					errorField = error;

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
	var div = document.createElement('div');
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
	
	var content = document.createTextNode(message.message);

	
	div.appendChild(b);
	div.appendChild(content);
	
	
	
	if (message.isSystemsMessage) {
		div.style = "padding: 1em 0.5em;margin:0.2em;background-color: coral;border-radius: 1em;";
	} else {
		div.style = "padding: 1em 0.5em;margin:0.2em;";
	}
	
	
	let list = document.getElementById("chatlist");
	
	list.prepend(div);
}
