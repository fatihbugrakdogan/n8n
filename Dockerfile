# Use the official n8n image as the base image
FROM n8nio/n8n

# Expose the necessary port
EXPOSE 5678

# Start n8n
CMD ["n8n", "start", "--tunnel"]
